import Foundation
import SwiftSignalKit
import CryptoUtils

public struct HashId: Hashable {
    public let data: Data
    
    public init(data: Data) {
        precondition(data.count == 16)
        self.data = data
    }
}

private func md5Hash(_ data: Data) -> HashId {
    let hashData = data.withUnsafeBytes { bytes -> Data in
        return CryptoMD5(bytes.baseAddress!, Int32(bytes.count))
    }
    return HashId(data: hashData)
}

public final class StorageBox {
    public struct Stats {
        public var contentTypes: [UInt8: Int64]
        
        public init(contentTypes: [UInt8: Int64]) {
            self.contentTypes = contentTypes
        }
    }
    
    public struct Reference {
        public var peerId: Int64
        public var messageNamespace: UInt8
        public var messageId: Int32
        
        public init(peerId: Int64, messageNamespace: UInt8, messageId: Int32) {
            self.peerId = peerId
            self.messageNamespace = messageNamespace
            self.messageId = messageId
        }
    }
    
    public final class Entry {
        public let id: Data
        public let references: [Reference]
        
        init(id: Data, references: [Reference]) {
            self.id = id
            self.references = references
        }
    }
    
    public final class Logger {
        private let impl: (String) -> Void
        
        public init(impl: @escaping (String) -> Void) {
            self.impl = impl
        }
        
        func log(_ string: @autoclosure () -> String) {
            self.impl(string())
        }
    }
    
    private struct ItemInfo {
        var id: Data
        var contentType: UInt8
        var size: Int64
        
        init(id: Data, contentType: UInt8, size: Int64) {
            self.id = id
            self.contentType = contentType
            self.size = size
        }
        
        init(buffer: MemoryBuffer) {
            var id = Data()
            var contentType: UInt8 = 0
            var size: Int64 = 0
            
            withExtendedLifetime(buffer, {
                let readBuffer = ReadBuffer(memoryBufferNoCopy: buffer)
                var version: UInt8 = 0
                readBuffer.read(&version, offset: 0, length: 1)
                let _ = version
                
                var idLength: UInt16 = 0
                readBuffer.read(&idLength, offset: 0, length: 2)
                id.count = Int(idLength)
                id.withUnsafeMutableBytes { buffer -> Void in
                    readBuffer.read(buffer.baseAddress!, offset: 0, length: buffer.count)
                }
                
                readBuffer.read(&contentType, offset: 0, length: 1)
                
                readBuffer.read(&size, offset: 0, length: 8)
            })
            
            self.id = id
            self.contentType = contentType
            self.size = size
        }
        
        func serialize() -> MemoryBuffer {
            let writeBuffer = WriteBuffer()
            
            var version: UInt8 = 0
            writeBuffer.write(&version, length: 1)
            
            var idLength = UInt16(clamping: self.id.count)
            writeBuffer.write(&idLength, length: 2)
            self.id.withUnsafeBytes { buffer in
                writeBuffer.write(buffer.baseAddress!, length: Int(idLength))
            }
            
            var contentType = self.contentType
            writeBuffer.write(&contentType, length: 1)
            
            var size = self.size
            writeBuffer.write(&size, length: 8)
            
            return writeBuffer
        }
    }
    
    private final class Impl {
        let queue: Queue
        let logger: StorageBox.Logger
        let basePath: String
        let valueBox: SqliteValueBox
        let hashIdToInfoTable: ValueBoxTable
        let idToReferenceTable: ValueBoxTable
        let peerIdToIdTable: ValueBoxTable
        let peerIdTable: ValueBoxTable
        let peerContentTypeStatsTable: ValueBoxTable
        let contentTypeStatsTable: ValueBoxTable
        
        init(queue: Queue, logger: StorageBox.Logger, basePath: String) {
            self.queue = queue
            self.logger = logger
            self.basePath = basePath
            
            let databasePath = self.basePath + "/db"
            let _ = try? FileManager.default.createDirectory(atPath: databasePath, withIntermediateDirectories: true)
            var valueBox = SqliteValueBox(basePath: databasePath, queue: queue, isTemporary: false, isReadOnly: false, useCaches: true, removeDatabaseOnError: true, encryptionParameters: nil, upgradeProgress: { _ in })
            if valueBox == nil {
                let _ = try? FileManager.default.removeItem(atPath: databasePath)
                valueBox = SqliteValueBox(basePath: databasePath, queue: queue, isTemporary: false, isReadOnly: false, useCaches: true, removeDatabaseOnError: true, encryptionParameters: nil, upgradeProgress: { _ in })
            }
            guard let valueBox else {
                preconditionFailure("Could not open database")
            }
            self.valueBox = valueBox
            
            self.hashIdToInfoTable = ValueBoxTable(id: 15, keyType: .binary, compactValuesOnCreation: true)
            self.idToReferenceTable = ValueBoxTable(id: 16, keyType: .binary, compactValuesOnCreation: true)
            self.peerIdToIdTable = ValueBoxTable(id: 17, keyType: .binary, compactValuesOnCreation: true)
            self.peerIdTable = ValueBoxTable(id: 18, keyType: .binary, compactValuesOnCreation: true)
            self.peerContentTypeStatsTable = ValueBoxTable(id: 19, keyType: .binary, compactValuesOnCreation: true)
            self.contentTypeStatsTable = ValueBoxTable(id: 20, keyType: .binary, compactValuesOnCreation: true)
        }
        
        private func internalAddSize(contentType: UInt8, delta: Int64) {
            let key = ValueBoxKey(length: 1)
            key.setUInt8(0, value: contentType)
            
            var currentSize: Int64 = 0
            if let value = self.valueBox.get(self.contentTypeStatsTable, key: key) {
                value.read(&currentSize, offset: 0, length: 8)
            }
            
            currentSize += delta
            
            if currentSize < 0 {
                assertionFailure()
                currentSize = 0
            }
            
            self.valueBox.set(self.contentTypeStatsTable, key: key, value: MemoryBuffer(memory: &currentSize, capacity: 8, length: 8, freeWhenDone: false))
        }
        
        private func internalAddSize(peerId: Int64, contentType: UInt8, delta: Int64) {
            let key = ValueBoxKey(length: 8 + 1)
            key.setInt64(0, value: peerId)
            key.setUInt8(8, value: contentType)
            
            var currentSize: Int64 = 0
            if let value = self.valueBox.get(self.contentTypeStatsTable, key: key) {
                value.read(&currentSize, offset: 0, length: 8)
            }
            
            currentSize += delta
            
            if currentSize < 0 {
                assertionFailure()
                currentSize = 0
            }
            
            self.valueBox.set(self.contentTypeStatsTable, key: key, value: MemoryBuffer(memory: &currentSize, capacity: 8, length: 8, freeWhenDone: false))
        }
        
        func add(reference: Reference, to id: Data, contentType: UInt8) {
            self.valueBox.begin()
            
            let hashId = md5Hash(id)
            
            let mainKey = ValueBoxKey(length: 16)
            mainKey.setData(0, value: hashId.data)
            
            var previousContentType: UInt8?
            var size: Int64 = 0
            if let currentInfoValue = self.valueBox.get(self.hashIdToInfoTable, key: mainKey) {
                var info = ItemInfo(buffer: currentInfoValue)
                if info.contentType != contentType {
                    previousContentType = info.contentType
                }
                size = info.size
                info.contentType = contentType
                self.valueBox.set(self.hashIdToInfoTable, key: mainKey, value: info.serialize())
            } else {
                self.valueBox.set(self.hashIdToInfoTable, key: mainKey, value: ItemInfo(id: id, contentType: contentType, size: 0).serialize())
            }
            
            if let previousContentType = previousContentType, previousContentType != contentType {
                if size != 0 {
                    self.internalAddSize(contentType: previousContentType, delta: -size)
                    self.internalAddSize(contentType: contentType, delta: size)
                }
            }
            
            let idKey = ValueBoxKey(length: hashId.data.count + 8 + 1 + 4)
            idKey.setData(0, value: hashId.data)
            idKey.setInt64(hashId.data.count, value: reference.peerId)
            idKey.setUInt8(hashId.data.count + 8, value: reference.messageNamespace)
            idKey.setInt32(hashId.data.count + 8 + 1, value: reference.messageId)
            
            var alreadyStored = false
            if !self.valueBox.exists(self.idToReferenceTable, key: idKey) {
                self.valueBox.setOrIgnore(self.idToReferenceTable, key: idKey, value: MemoryBuffer())
            } else {
                alreadyStored = true
            }
            
            if !alreadyStored {
                var idInPeerIdStored = false
                
                let peerIdIdKey = ValueBoxKey(length: 8 + 16)
                peerIdIdKey.setInt64(0, value: reference.peerId)
                peerIdIdKey.setData(8, value: hashId.data)
                var peerIdIdCount: Int32 = 0
                if let value = self.valueBox.get(self.peerIdToIdTable, key: peerIdIdKey) {
                    idInPeerIdStored = true
                    if value.length == 4 {
                        memcpy(&peerIdIdCount, value.memory, 4)
                    } else {
                        assertionFailure()
                    }
                }
                peerIdIdCount += 1
                self.valueBox.set(self.peerIdToIdTable, key: peerIdIdKey, value: MemoryBuffer(memory: &peerIdIdCount, capacity: 4, length: 4, freeWhenDone: false))
                
                if !idInPeerIdStored {
                    let peerIdKey = ValueBoxKey(length: 8)
                    peerIdKey.setInt64(0, value: reference.peerId)
                    var peerIdCount: Int32 = 0
                    if let value = self.valueBox.get(self.peerIdTable, key: peerIdKey) {
                        if value.length == 4 {
                            memcpy(&peerIdCount, value.memory, 4)
                        } else {
                            assertionFailure()
                        }
                    }
                    peerIdCount += 1
                    self.valueBox.set(self.peerIdTable, key: peerIdKey, value: MemoryBuffer(memory: &peerIdCount, capacity: 4, length: 4, freeWhenDone: false))
                }
            }
            
            self.valueBox.commit()
        }
        
        func update(id: Data, size: Int64) {
            self.valueBox.begin()
            
            let hashId = md5Hash(id)
            
            let mainKey = ValueBoxKey(length: 16)
            mainKey.setData(0, value: hashId.data)
            
            if let currentInfoValue = self.valueBox.get(self.hashIdToInfoTable, key: mainKey) {
                var info = ItemInfo(buffer: currentInfoValue)
                
                var sizeDelta: Int64 = 0
                if info.size != size {
                    sizeDelta = size - info.size
                    info.size = size
                    
                    self.valueBox.set(self.hashIdToInfoTable, key: mainKey, value: info.serialize())
                }
                
                if sizeDelta != 0 {
                    self.internalAddSize(contentType: info.contentType, delta: sizeDelta)
                }
                
                var peerIds: [Int64] = []
                self.valueBox.range(self.idToReferenceTable, start: mainKey, end: mainKey.successor, keys: { key in
                    peerIds.append(key.getInt64(0))
                    return true
                }, limit: 0)
                
                for peerId in peerIds {
                    let _ = peerId
                }
            }
            
            self.valueBox.commit()
        }
        
        func addEmptyReferencesIfNotReferenced(ids: [(id: Data, size: Int64)], contentType: UInt8) -> Int {
            self.valueBox.begin()
            
            var addedCount = 0
            
            for (id, size) in ids {
                let reference = Reference(peerId: 0, messageNamespace: 0, messageId: 0)
                
                let hashId = md5Hash(id)
                
                let mainKey = ValueBoxKey(length: 16)
                mainKey.setData(0, value: hashId.data)
                if self.valueBox.exists(self.hashIdToInfoTable, key: mainKey) {
                    continue
                }
                
                addedCount += 1
                
                self.valueBox.set(self.hashIdToInfoTable, key: mainKey, value: ItemInfo(id: id, contentType: contentType, size: size).serialize())
                
                let idKey = ValueBoxKey(length: hashId.data.count + 8 + 1 + 4)
                idKey.setData(0, value: hashId.data)
                idKey.setInt64(hashId.data.count, value: reference.peerId)
                idKey.setUInt8(hashId.data.count + 8, value: reference.messageNamespace)
                idKey.setInt32(hashId.data.count + 8 + 1, value: reference.messageId)
                
                var alreadyStored = false
                if !self.valueBox.exists(self.idToReferenceTable, key: idKey) {
                    self.valueBox.setOrIgnore(self.idToReferenceTable, key: idKey, value: MemoryBuffer())
                } else {
                    alreadyStored = true
                }
                
                if !alreadyStored {
                    var idInPeerIdStored = false
                    
                    let peerIdIdKey = ValueBoxKey(length: 8 + 16)
                    peerIdIdKey.setInt64(0, value: reference.peerId)
                    peerIdIdKey.setData(8, value: hashId.data)
                    var peerIdIdCount: Int32 = 0
                    if let value = self.valueBox.get(self.peerIdToIdTable, key: peerIdIdKey) {
                        idInPeerIdStored = true
                        if value.length == 4 {
                            memcpy(&peerIdIdCount, value.memory, 4)
                        } else {
                            assertionFailure()
                        }
                    }
                    peerIdIdCount += 1
                    self.valueBox.set(self.peerIdToIdTable, key: peerIdIdKey, value: MemoryBuffer(memory: &peerIdIdCount, capacity: 4, length: 4, freeWhenDone: false))
                    
                    if !idInPeerIdStored {
                        let peerIdKey = ValueBoxKey(length: 8)
                        peerIdKey.setInt64(0, value: reference.peerId)
                        var peerIdCount: Int32 = 0
                        if let value = self.valueBox.get(self.peerIdTable, key: peerIdKey) {
                            if value.length == 4 {
                                memcpy(&peerIdCount, value.memory, 4)
                            } else {
                                assertionFailure()
                            }
                        }
                        peerIdCount += 1
                        self.valueBox.set(self.peerIdTable, key: peerIdKey, value: MemoryBuffer(memory: &peerIdCount, capacity: 4, length: 4, freeWhenDone: false))
                    }
                }
            }
            
            self.valueBox.commit()
            
            return addedCount
        }
        
        func remove(ids: [Data]) {
            self.valueBox.begin()
            
            let mainKey = ValueBoxKey(length: 16)
            let peerIdIdKey = ValueBoxKey(length: 8 + 16)
            let peerIdKey = ValueBoxKey(length: 8)
            
            for id in ids {
                let hashId = md5Hash(id)
                mainKey.setData(0, value: hashId.data)
                
                guard let infoValue = self.valueBox.get(self.hashIdToInfoTable, key: mainKey) else {
                    continue
                }
                let info = ItemInfo(buffer: infoValue)
                self.valueBox.remove(self.hashIdToInfoTable, key: mainKey, secure: false)
                
                if info.size != 0 {
                    self.internalAddSize(contentType: info.contentType, delta: -info.size)
                }
                
                var referenceKeys: [ValueBoxKey] = []
                self.valueBox.range(self.idToReferenceTable, start: mainKey, end: mainKey.successor, keys: { key in
                    referenceKeys.append(key)
                    return true
                }, limit: 0)
                var peerIds = Set<Int64>()
                for key in referenceKeys {
                    peerIds.insert(key.getInt64(16))
                    self.valueBox.remove(self.idToReferenceTable, key: key, secure: false)
                }
                
                for peerId in peerIds {
                    peerIdIdKey.setInt64(0, value: peerId)
                    peerIdIdKey.setData(8, value: hashId.data)
                    
                    if self.valueBox.exists(self.peerIdToIdTable, key: peerIdIdKey) {
                        self.valueBox.remove(self.peerIdToIdTable, key: peerIdIdKey, secure: false)
                        
                        peerIdKey.setInt64(0, value: peerId)
                        if let value = self.valueBox.get(self.peerIdTable, key: peerIdKey) {
                            var peerIdCount: Int32 = 0
                            if value.length == 4 {
                                memcpy(&peerIdCount, value.memory, 4)
                            } else {
                                assertionFailure()
                            }
                            
                            peerIdCount -= 1
                            if peerIdCount > 0 {
                                self.valueBox.set(self.peerIdTable, key: peerIdKey, value: MemoryBuffer(memory: &peerIdCount, capacity: 4, length: 4, freeWhenDone: false))
                            } else {
                                self.valueBox.remove(self.peerIdTable, key: peerIdKey, secure: false)
                            }
                        }
                    }
                }
            }
            
            self.valueBox.commit()
        }
        
        func allPeerIds() -> [PeerId] {
            var result: [PeerId] = []
            
            self.valueBox.begin()
            
            self.valueBox.scan(self.peerIdTable, keys: { key in
                result.append(PeerId(key.getInt64(0)))
                return true
            })
            
            self.valueBox.commit()
            
            return result
        }
        
        func all(peerId: PeerId) -> [Data] {
            self.valueBox.begin()
            
            var hashIds: [Data] = []
            let peerIdIdKey = ValueBoxKey(length: 8)
            peerIdIdKey.setInt64(0, value: peerId.toInt64())
            self.valueBox.range(self.peerIdToIdTable, start: peerIdIdKey, end: peerIdIdKey.successor, keys: { key in
                hashIds.append(key.getData(8, length: 16))
                return true
            }, limit: 0)
            
            var result: [Data] = []
            let mainKey = ValueBoxKey(length: 16)
            for hashId in hashIds {
                mainKey.setData(0, value: hashId)
                if let infoValue = self.valueBox.get(self.hashIdToInfoTable, key: mainKey) {
                    let info = ItemInfo(buffer: infoValue)
                    result.append(info.id)
                }
            }
            
            self.valueBox.commit()
            
            return result
        }
        
        func all() -> [Entry] {
            var result: [Entry] = []
            
            self.valueBox.begin()
            
            var currentId: Data?
            var currentReferences: [Reference] = []
            
            let mainKey = ValueBoxKey(length: 16)
            
            self.valueBox.scan(self.idToReferenceTable, keys: { key in
                let id = key.getData(0, length: 16)
                
                let peerId = key.getInt64(16)
                let messageNamespace: UInt8 = key.getUInt8(16 + 8)
                let messageId = key.getInt32(16 + 8 + 1)
                
                let reference = Reference(peerId: peerId, messageNamespace: messageNamespace, messageId: messageId)
                
                if currentId == id {
                    currentReferences.append(reference)
                } else {
                    if let currentId = currentId, !currentReferences.isEmpty {
                        mainKey.setData(0, value: currentId)
                        if let infoValue = self.valueBox.get(self.hashIdToInfoTable, key: mainKey) {
                            let info = ItemInfo(buffer: infoValue)
                            result.append(StorageBox.Entry(id: info.id, references: currentReferences))
                        }
                        currentReferences.removeAll(keepingCapacity: true)
                    }
                    currentId = id
                    currentReferences.append(reference)
                }
                
                return true
            })
            
            self.valueBox.commit()
            
            return result
        }
        
        func get(ids: [Data]) -> [Entry] {
            var result: [Entry] = []
            
            self.valueBox.begin()
            
            let idKey = ValueBoxKey(length: 16)
            
            for id in ids {
                let hashId = md5Hash(id)
                idKey.setData(0, value: hashId.data)
                var currentReferences: [Reference] = []
                self.valueBox.range(self.idToReferenceTable, start: idKey, end: idKey.successor, keys: { key in
                    let peerId = key.getInt64(16)
                    let messageNamespace: UInt8 = key.getUInt8(16 + 8)
                    let messageId = key.getInt32(16 + 8 + 1)
                    
                    let reference = Reference(peerId: peerId, messageNamespace: messageNamespace, messageId: messageId)
                    
                    currentReferences.append(reference)
                    return true
                }, limit: 0)
                
                if !currentReferences.isEmpty {
                    result.append(StorageBox.Entry(id: id, references: currentReferences))
                }
            }
            
            self.valueBox.commit()
            
            return result
        }
        
        func getStats() -> Stats {
            var contentTypes: [UInt8: Int64] = [:]
            
            self.valueBox.scan(self.contentTypeStatsTable, values: { key, value in
                var size: Int64 = 0
                value.read(&size, offset: 0, length: 8)
                contentTypes[key.getUInt8(0)] = size
                
                return true
            })
            
            return Stats(contentTypes: contentTypes)
        }
    }
    
    private let queue: Queue
    private let impl: QueueLocalObject<Impl>
    
    public init(queue: Queue = Queue(name: "StorageBox"), logger: StorageBox.Logger, basePath: String) {
        self.queue = queue
        self.impl = QueueLocalObject(queue: queue, generate: {
            return Impl(queue: queue, logger: logger, basePath: basePath)
        })
    }
    
    public func add(reference: Reference, to id: Data, contentType: UInt8) {
        self.impl.with { impl in
            impl.add(reference: reference, to: id, contentType: contentType)
        }
    }
    
    public func update(id: Data, size: Int64) {
        self.impl.with { impl in
            impl.update(id: id, size: size)
        }
    }
    
    public func addEmptyReferencesIfNotReferenced(ids: [(id: Data, size: Int64)], contentType: UInt8, completion: @escaping (Int) -> Void) {
        self.impl.with { impl in
            let addedCount = impl.addEmptyReferencesIfNotReferenced(ids: ids, contentType: contentType)
            
            completion(addedCount)
        }
    }
    
    public func remove(ids: [Data]) {
        self.impl.with { impl in
            impl.remove(ids: ids)
        }
    }
    
    public func all() -> Signal<[Entry], NoError> {
        return self.impl.signalWith { impl, subscriber in
            subscriber.putNext(impl.all())
            subscriber.putCompletion()
            
            return EmptyDisposable
        }
    }
    
    public func allPeerIds() -> Signal<[PeerId], NoError> {
        return self.impl.signalWith { impl, subscriber in
            subscriber.putNext(impl.allPeerIds())
            subscriber.putCompletion()
            
            return EmptyDisposable
        }
    }
    
    public func all(peerId: PeerId) -> Signal<[Data], NoError> {
        return self.impl.signalWith { impl, subscriber in
            subscriber.putNext(impl.all(peerId: peerId))
            subscriber.putCompletion()
            
            return EmptyDisposable
        }
    }
    
    public func get(ids: [Data]) -> Signal<[Entry], NoError> {
        return self.impl.signalWith { impl, subscriber in
            subscriber.putNext(impl.get(ids: ids))
            subscriber.putCompletion()
            
            return EmptyDisposable
        }
    }
    
    public func getStats() -> Signal<Stats, NoError> {
        return self.impl.signalWith { impl, subscriber in
            subscriber.putNext(impl.getStats())
            subscriber.putCompletion()
            
            return EmptyDisposable
        }
    }
}
