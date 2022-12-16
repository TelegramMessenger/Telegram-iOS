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
    
    private final class Impl {
        let queue: Queue
        let logger: StorageBox.Logger
        let basePath: String
        let valueBox: SqliteValueBox
        let hashIdToIdTable: ValueBoxTable
        let idToReferenceTable: ValueBoxTable
        let peerIdToIdTable: ValueBoxTable
        let peerIdTable: ValueBoxTable
        
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
            
            self.hashIdToIdTable = ValueBoxTable(id: 5, keyType: .binary, compactValuesOnCreation: true)
            self.idToReferenceTable = ValueBoxTable(id: 6, keyType: .binary, compactValuesOnCreation: true)
            self.peerIdToIdTable = ValueBoxTable(id: 7, keyType: .binary, compactValuesOnCreation: true)
            self.peerIdTable = ValueBoxTable(id: 8, keyType: .binary, compactValuesOnCreation: true)
        }
        
        func add(reference: Reference, to id: Data) {
            self.valueBox.begin()
            
            let hashId = md5Hash(id)
            
            let mainKey = ValueBoxKey(length: 16)
            mainKey.setData(0, value: hashId.data)
            self.valueBox.setOrIgnore(self.hashIdToIdTable, key: mainKey, value: MemoryBuffer(data: id))
            
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
        
        func addEmptyReferencesIfNotReferenced(ids: [Data]) -> Int {
            self.valueBox.begin()
            
            var addedCount = 0
            
            for id in ids {
                let reference = Reference(peerId: 0, messageNamespace: 0, messageId: 0)
                
                let hashId = md5Hash(id)
                
                let mainKey = ValueBoxKey(length: 16)
                mainKey.setData(0, value: hashId.data)
                if self.valueBox.exists(self.hashIdToIdTable, key: mainKey) {
                    continue
                }
                
                addedCount += 1
                
                self.valueBox.setOrIgnore(self.hashIdToIdTable, key: mainKey, value: MemoryBuffer(data: id))
                
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
                
                self.valueBox.remove(self.hashIdToIdTable, key: mainKey, secure: false)
                
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
                if let value = self.valueBox.get(self.hashIdToIdTable, key: mainKey) {
                    result.append(value.makeData())
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
                        if let value = self.valueBox.get(self.hashIdToIdTable, key: mainKey) {
                            result.append(StorageBox.Entry(id: value.makeData(), references: currentReferences))
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
    }
    
    private let queue: Queue
    private let impl: QueueLocalObject<Impl>
    
    public init(queue: Queue = Queue(name: "StorageBox"), logger: StorageBox.Logger, basePath: String) {
        self.queue = queue
        self.impl = QueueLocalObject(queue: queue, generate: {
            return Impl(queue: queue, logger: logger, basePath: basePath)
        })
    }
    
    public func add(reference: Reference, to id: Data) {
        self.impl.with { impl in
            impl.add(reference: reference, to: id)
        }
    }
    
    public func addEmptyReferencesIfNotReferenced(ids: [Data], completion: @escaping (Int) -> Void) {
        self.impl.with { impl in
            let addedCount = impl.addEmptyReferencesIfNotReferenced(ids: ids)
            
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
}
