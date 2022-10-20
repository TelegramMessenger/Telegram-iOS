import Foundation

enum PeerMergedOperationLogOperation {
    case append(PeerMergedOperationLogEntry)
    case remove(tag: PeerOperationLogTag, mergedIndices: Set<Int32>)
    case updateContents(PeerMergedOperationLogEntry)
}

public struct PeerMergedOperationLogEntry {
    public let peerId: PeerId
    public let tag: PeerOperationLogTag
    public let tagLocalIndex: Int32
    public let mergedIndex: Int32
    public let contents: PostboxCoding
}

public enum StorePeerOperationLogEntryTagLocalIndex {
    case automatic
    case manual(Int32)
}

public enum StorePeerOperationLogEntryTagMergedIndex {
    case none
    case automatic
}

public struct PeerOperationLogEntry {
    public let peerId: PeerId
    public let tag: PeerOperationLogTag
    public let tagLocalIndex: Int32
    public let mergedIndex: Int32?
    public let contents: PostboxCoding
    
    public func withUpdatedContents(_ contents: PostboxCoding) -> PeerOperationLogEntry {
        return PeerOperationLogEntry(peerId: self.peerId, tag: self.tag, tagLocalIndex: self.tagLocalIndex, mergedIndex: self.mergedIndex, contents: contents)
    }
    
    public var mergedEntry: PeerMergedOperationLogEntry? {
        if let mergedIndex = self.mergedIndex {
            return PeerMergedOperationLogEntry(peerId: self.peerId, tag: self.tag, tagLocalIndex: self.tagLocalIndex, mergedIndex: mergedIndex, contents: self.contents)
        } else {
            return nil
        }
    }
}

public struct PeerOperationLogTag: Equatable {
    let rawValue: UInt8
    
    public init(value: Int) {
        self.rawValue = UInt8(value)
    }
    
    public static func ==(lhs: PeerOperationLogTag, rhs: PeerOperationLogTag) -> Bool {
        return lhs.rawValue == rhs.rawValue
    }
}

public enum PeerOperationLogEntryUpdateContents {
    case none
    case update(PostboxCoding)
}

public enum PeerOperationLogEntryUpdateTagMergedIndex {
    case none
    case remove
    case newAutomatic
}

public struct PeerOperationLogEntryUpdate {
    let mergedIndex: PeerOperationLogEntryUpdateTagMergedIndex
    let contents: PeerOperationLogEntryUpdateContents
    
    public init(mergedIndex: PeerOperationLogEntryUpdateTagMergedIndex, contents: PeerOperationLogEntryUpdateContents) {
        self.mergedIndex = mergedIndex
        self.contents = contents
    }
}

private func parseEntry(peerId: PeerId, tag: PeerOperationLogTag, tagLocalIndex: Int32, _ value: ReadBuffer) -> PeerOperationLogEntry? {
    var hasMergedIndex: Int8 = 0
    value.read(&hasMergedIndex, offset: 0, length: 1)
    var mergedIndex: Int32?
    if hasMergedIndex != 0 {
        var mergedIndexValue: Int32 = 0
        value.read(&mergedIndexValue, offset: 0, length: 4)
        mergedIndex = mergedIndexValue
    }
    var contentLength: Int32 = 0
    value.read(&contentLength, offset: 0, length: 4)
    assert(value.length - value.offset == Int(contentLength))
    if let contents = PostboxDecoder(buffer: MemoryBuffer(memory: value.memory.advanced(by: value.offset), capacity: Int(contentLength), length: Int(contentLength), freeWhenDone: false)).decodeRootObject() {
        return PeerOperationLogEntry(peerId: peerId, tag: tag, tagLocalIndex: tagLocalIndex, mergedIndex: mergedIndex, contents: contents)
    } else {
        return nil
    }
}

private func parseMergedEntry(peerId: PeerId, tag: PeerOperationLogTag, tagLocalIndex: Int32, _ value: ReadBuffer) -> PeerMergedOperationLogEntry? {
    if let entry = parseEntry(peerId: peerId, tag: tag, tagLocalIndex: tagLocalIndex, value), let mergedIndex = entry.mergedIndex {
        return PeerMergedOperationLogEntry(peerId: entry.peerId, tag: entry.tag, tagLocalIndex: entry.tagLocalIndex, mergedIndex: mergedIndex, contents: entry.contents)
    } else {
        return nil
    }
}

final class PeerOperationLogTable: Table {
    static func tableSpec(_ id: Int32) -> ValueBoxTable {
        return ValueBoxTable(id: id, keyType: .binary, compactValuesOnCreation: false)
    }
    
    private let metadataTable: PeerOperationLogMetadataTable
    private let mergedIndexTable: PeerMergedOperationLogIndexTable
    
    init(valueBox: ValueBox, table: ValueBoxTable, useCaches: Bool, metadataTable: PeerOperationLogMetadataTable, mergedIndexTable: PeerMergedOperationLogIndexTable) {
        self.metadataTable = metadataTable
        self.mergedIndexTable = mergedIndexTable
        
        super.init(valueBox: valueBox, table: table, useCaches: useCaches)
    }
    
    private func key(peerId: PeerId, tag: PeerOperationLogTag, index: Int32) -> ValueBoxKey {
        let key = ValueBoxKey(length: 8 + 1 + 4)
        key.setInt64(0, value: peerId.toInt64())
        key.setUInt8(8, value: tag.rawValue)
        key.setInt32(9, value: index)
        return key
    }
    
    func getNextEntryLocalIndex(peerId: PeerId, tag: PeerOperationLogTag) -> Int32 {
        return self.metadataTable.getNextLocalIndex(peerId: peerId, tag: tag)
    }
    
    func resetIndices(peerId: PeerId, tag: PeerOperationLogTag, nextTagLocalIndex: Int32) {
        self.metadataTable.setNextLocalIndex(peerId: peerId, tag: tag, index: nextTagLocalIndex)
    }
    
    func addEntry(peerId: PeerId, tag: PeerOperationLogTag, tagLocalIndex: StorePeerOperationLogEntryTagLocalIndex, tagMergedIndex: StorePeerOperationLogEntryTagMergedIndex, contents: PostboxCoding, operations: inout [PeerMergedOperationLogOperation]) {
        let index: Int32
        switch tagLocalIndex {
            case .automatic:
                index = self.metadataTable.takeNextLocalIndex(peerId: peerId, tag: tag)
            case let .manual(manualIndex):
                index = manualIndex
        }
        
        var mergedIndex: Int32?
        switch tagMergedIndex {
            case .automatic:
                mergedIndex = self.mergedIndexTable.add(peerId: peerId, tag: tag, tagLocalIndex: index)
            case .none:
                break
        }
        
        let buffer = WriteBuffer()
        var hasMergedIndex: Int8 = mergedIndex != nil ? 1 : 0
        buffer.write(&hasMergedIndex, offset: 0, length: 1)
        if let mergedIndex = mergedIndex {
            var mergedIndexValue: Int32 = mergedIndex
            buffer.write(&mergedIndexValue, offset: 0, length: 4)
        }
        
        let encoder = PostboxEncoder()
        encoder.encodeRootObject(contents)
        withExtendedLifetime(encoder, {
            let contentBuffer = encoder.readBufferNoCopy()
            var contentBufferLength: Int32 = Int32(contentBuffer.length)
            buffer.write(&contentBufferLength, offset: 0, length: 4)
            buffer.write(contentBuffer.memory, offset: 0, length: contentBuffer.length)
        })
        
        self.valueBox.set(self.table, key: self.key(peerId: peerId, tag: tag, index: index), value: buffer)
        if let mergedIndex = mergedIndex {
            operations.append(.append(PeerMergedOperationLogEntry(peerId: peerId, tag: tag, tagLocalIndex: index, mergedIndex: mergedIndex, contents: contents)))
        }
    }
    
    func removeEntry(peerId: PeerId, tag: PeerOperationLogTag, tagLocalIndex index: Int32, operations: inout [PeerMergedOperationLogOperation]) -> Bool {
        var indices: [Int32] = []
        var mergedIndices: [Int32] = []
        var removed = false
        if let value = self.valueBox.get(self.table, key: self.key(peerId: peerId, tag: tag, index: index)) {
            indices.append(index)
            var hasMergedIndex: Int8 = 0
            value.read(&hasMergedIndex, offset: 0, length: 1)
            if hasMergedIndex != 0 {
                var mergedIndex: Int32 = 0
                value.read(&mergedIndex, offset: 0, length: 4)
                mergedIndices.append(mergedIndex)
            }
            removed = true
        }
        
        for index in indices {
            self.valueBox.remove(self.table, key: self.key(peerId: peerId, tag: tag, index: index), secure: false)
        }
        
        if !mergedIndices.isEmpty {
            self.mergedIndexTable.remove(tag: tag, mergedIndices: mergedIndices)
            operations.append(.remove(tag: tag, mergedIndices: Set(mergedIndices)))
        }
        return removed
    }
    
    func removeAllEntries(peerId: PeerId, tag: PeerOperationLogTag, operations: inout [PeerMergedOperationLogOperation]) {
        var indices: [Int32] = []
        var mergedIndices: [Int32] = []
        self.valueBox.range(self.table, start: self.key(peerId: peerId, tag: tag, index: 0).predecessor, end: self.key(peerId: peerId, tag: tag, index: Int32.max).successor, values: { key, value in
            let index = key.getInt32(9)
            indices.append(index)
            var hasMergedIndex: Int8 = 0
            value.read(&hasMergedIndex, offset: 0, length: 1)
            if hasMergedIndex != 0 {
                var mergedIndex: Int32 = 0
                value.read(&mergedIndex, offset: 0, length: 4)
                mergedIndices.append(mergedIndex)
            }
            return true
        }, limit: 0)
        
        for index in indices {
            self.valueBox.remove(self.table, key: self.key(peerId: peerId, tag: tag, index: index), secure: false)
        }
        
        if !mergedIndices.isEmpty {
            self.mergedIndexTable.remove(tag: tag, mergedIndices: mergedIndices)
            operations.append(.remove(tag: tag, mergedIndices: Set(mergedIndices)))
        }
    }
    
    func removeEntries(peerId: PeerId, tag: PeerOperationLogTag, withTagLocalIndicesEqualToOrLowerThan maxTagLocalIndex: Int32, operations: inout [PeerMergedOperationLogOperation]) {
        var indices: [Int32] = []
        var mergedIndices: [Int32] = []
        self.valueBox.range(self.table, start: self.key(peerId: peerId, tag: tag, index: 0).predecessor, end: self.key(peerId: peerId, tag: tag, index: maxTagLocalIndex).successor, values: { key, value in
            let index = key.getInt32(9)
            indices.append(index)
            var hasMergedIndex: Int8 = 0
            value.read(&hasMergedIndex, offset: 0, length: 1)
            if hasMergedIndex != 0 {
                var mergedIndex: Int32 = 0
                value.read(&mergedIndex, offset: 0, length: 4)
                mergedIndices.append(mergedIndex)
            }
            return true
        }, limit: 0)
        
        for index in indices {
            self.valueBox.remove(self.table, key: self.key(peerId: peerId, tag: tag, index: index), secure: false)
        }
        
        if !mergedIndices.isEmpty {
            self.mergedIndexTable.remove(tag: tag, mergedIndices: mergedIndices)
            operations.append(.remove(tag: tag, mergedIndices: Set(mergedIndices)))
        }
    }
    
    func getMergedEntries(tag: PeerOperationLogTag, fromIndex: Int32, limit: Int) -> [PeerMergedOperationLogEntry] {
        var entries: [PeerMergedOperationLogEntry] = []
        for (peerId, tagLocalIndex, mergedIndex) in self.mergedIndexTable.getTagLocalIndices(tag: tag, fromMergedIndex: fromIndex, limit: limit) {
            if let value = self.valueBox.get(self.table, key: self.key(peerId: peerId, tag: tag, index: tagLocalIndex)) {
                if let entry = parseMergedEntry(peerId: peerId, tag: tag, tagLocalIndex: tagLocalIndex, value) {
                    entries.append(entry)
                } else {
                    assertionFailure()
                }
            } else {
                self.mergedIndexTable.remove(tag: tag, mergedIndices: [mergedIndex])
                assertionFailure()
            }
        }
        return entries
    }
    
    func enumerateEntries(peerId: PeerId, tag: PeerOperationLogTag, _ f: (PeerOperationLogEntry) -> Bool) {
        self.valueBox.range(self.table, start: self.key(peerId: peerId, tag: tag, index: 0).predecessor, end: self.key(peerId: peerId, tag: tag, index: Int32.max).successor, values: { key, value in
            if let entry = parseEntry(peerId: peerId, tag: tag, tagLocalIndex: key.getInt32(9), value) {
                if !f(entry) {
                    return false
                }
            } else {
                assertionFailure()
            }
            return true
        }, limit: 0)
    }
    
    func updateEntry(peerId: PeerId, tag: PeerOperationLogTag, tagLocalIndex: Int32, f: (PeerOperationLogEntry?) -> PeerOperationLogEntryUpdate, operations: inout [PeerMergedOperationLogOperation]) {
        let key = self.key(peerId: peerId, tag: tag, index: tagLocalIndex)
        if let value = self.valueBox.get(self.table, key: key) {
            var hasMergedIndex: Int8 = 0
            value.read(&hasMergedIndex, offset: 0, length: 1)
            var mergedIndex: Int32?
            if hasMergedIndex != 0 {
                var mergedIndexValue: Int32 = 0
                value.read(&mergedIndexValue, offset: 0, length: 4)
                mergedIndex = mergedIndexValue
            }
            let previousMergedIndex = mergedIndex
            var contentLength: Int32 = 0
            value.read(&contentLength, offset: 0, length: 4)
            assert(value.length - value.offset == Int(contentLength))
            if let contents = PostboxDecoder(buffer: MemoryBuffer(memory: value.memory.advanced(by: value.offset), capacity: Int(contentLength), length: Int(contentLength), freeWhenDone: false)).decodeRootObject() {
                let entryUpdate = f(PeerOperationLogEntry(peerId: peerId, tag: tag, tagLocalIndex: tagLocalIndex, mergedIndex: mergedIndex, contents: contents))
                var updatedContents: PostboxCoding?
                switch entryUpdate.contents {
                    case .none:
                        break
                    case let .update(contents):
                        updatedContents = contents
                }
                switch entryUpdate.mergedIndex {
                    case .none:
                        if let previousMergedIndex = previousMergedIndex, let updatedContents = updatedContents {
                            operations.append(.updateContents(PeerMergedOperationLogEntry(peerId: peerId, tag: tag, tagLocalIndex: tagLocalIndex, mergedIndex: previousMergedIndex, contents: updatedContents)))
                        }
                    case .remove:
                        if let mergedIndexValue = mergedIndex {
                            mergedIndex = nil
                            self.mergedIndexTable.remove(tag: tag, mergedIndices: [mergedIndexValue])
                            operations.append(.remove(tag: tag, mergedIndices: Set([mergedIndexValue])))
                        }
                    case .newAutomatic:
                        if let mergedIndexValue = mergedIndex {
                            self.mergedIndexTable.remove(tag: tag, mergedIndices: [mergedIndexValue])
                            operations.append(.remove(tag: tag, mergedIndices: Set([mergedIndexValue])))
                        }
                        let updatedMergedIndexValue = self.mergedIndexTable.add(peerId: peerId, tag: tag, tagLocalIndex: tagLocalIndex)
                        mergedIndex = updatedMergedIndexValue
                        operations.append(.append(PeerMergedOperationLogEntry(peerId: peerId, tag: tag, tagLocalIndex: tagLocalIndex, mergedIndex: updatedMergedIndexValue, contents: updatedContents ?? contents)))
                }
                if previousMergedIndex != mergedIndex || updatedContents != nil {
                    let buffer = WriteBuffer()
                    var hasMergedIndex: Int8 = mergedIndex != nil ? 1 : 0
                    buffer.write(&hasMergedIndex, offset: 0, length: 1)
                    if let mergedIndex = mergedIndex {
                        var mergedIndexValue: Int32 = mergedIndex
                        buffer.write(&mergedIndexValue, offset: 0, length: 4)
                    }
                    
                    let encoder = PostboxEncoder()
                    if let updatedContents = updatedContents {
                        encoder.encodeRootObject(updatedContents)
                    } else {
                        encoder.encodeRootObject(contents)
                    }
                    let contentBuffer = encoder.readBufferNoCopy()
                    withExtendedLifetime(encoder, {
                        var contentBufferLength: Int32 = Int32(contentBuffer.length)
                        buffer.write(&contentBufferLength, offset: 0, length: 4)
                        buffer.write(contentBuffer.memory, offset: 0, length: contentBuffer.length)
                        self.valueBox.set(self.table, key: key, value: buffer)
                    })
                }
            } else {
                assertionFailure()
            }
        } else {
            let _ = f(nil)
        }
    }
}
