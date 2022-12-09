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
        public var peerId: PeerId
        public var messageNamespace: UInt8
        public var messageId: Int32
        
        public init(peerId: PeerId, messageNamespace: UInt8, messageId: Int32) {
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
        }
        
        func add(reference: Reference, to id: Data) {
            self.valueBox.begin()
            
            let hashId = md5Hash(id)
            
            let mainKey = ValueBoxKey(length: hashId.data.count)
            self.valueBox.setOrIgnore(self.hashIdToIdTable, key: mainKey, value: MemoryBuffer(data: id))
            
            let idKey = ValueBoxKey(length: hashId.data.count + 8 + 1 + 4)
            idKey.setData(0, value: hashId.data)
            idKey.setInt64(hashId.data.count, value: reference.peerId.toInt64())
            idKey.setUInt8(hashId.data.count + 8, value: reference.messageNamespace)
            idKey.setInt32(hashId.data.count + 8 + 1, value: reference.messageId)
            self.valueBox.setOrIgnore(self.idToReferenceTable, key: idKey, value: MemoryBuffer())
            
            self.valueBox.commit()
        }
        
        func all() -> [Entry] {
            var result: [Entry] = []
            
            self.valueBox.begin()
            
            var currentId: Data?
            var currentReferences: [Reference] = []
            
            self.valueBox.scan(self.idToReferenceTable, keys: { key in
                let id = key.getData(0, length: 16)
                
                let peerId = PeerId(key.getInt64(16))
                let messageNamespace: UInt8 = key.getUInt8(16 + 8)
                let messageId = key.getInt32(16 + 8 + 1)
                
                let reference = Reference(peerId: peerId, messageNamespace: messageNamespace, messageId: messageId)
                
                if currentId == id {
                    currentReferences.append(reference)
                } else {
                    if let currentId = currentId, !currentReferences.isEmpty {
                        result.append(StorageBox.Entry(id: currentId, references: currentReferences))
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
                    let peerId = PeerId(key.getInt64(16))
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
    
    public func all() -> Signal<[Entry], NoError> {
        return self.impl.signalWith { impl, subscriber in
            subscriber.putNext(impl.all())
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
