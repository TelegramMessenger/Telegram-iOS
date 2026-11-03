import Foundation

public struct UnorderedItemListEntryInfo {
    public let hashValue: Int64
    
    public init(hashValue: Int64) {
        self.hashValue = hashValue
    }
}

public struct UnorderedItemListEntry {
    public let id: ValueBoxKey
    public let info: UnorderedItemListEntryInfo
    public let contents: PostboxCoding
    
    public init(id: ValueBoxKey, info: UnorderedItemListEntryInfo, contents: PostboxCoding) {
        self.id = id
        self.info = info
        self.contents = contents
    }
}

public struct UnorderedItemListEntryTag {
    public let value: ValueBoxKey
    
    public init(value: ValueBoxKey) {
        self.value = value
    }
}

public protocol UnorderedItemListTagMetaInfo: PostboxCoding {
    func isEqual(to: UnorderedItemListTagMetaInfo) -> Bool
}

private enum UnorderedItemListTableKeyspace: UInt8 {
    case metaInfo = 0
    case entries = 1
}

private func extractEntryKey(tagLength: Int, key: ValueBoxKey) -> ValueBoxKey {
    let result = ValueBoxKey(length: key.length - tagLength - 1)
    memcpy(result.memory, key.memory.advanced(by: 1 + tagLength), result.length)
    return result
}

private func extractEntryInfo(_ value: ReadBuffer) -> UnorderedItemListEntryInfo {
    var hashValue: Int64 = 0
    value.read(&hashValue, offset: 0, length: 8)
    return UnorderedItemListEntryInfo(hashValue: hashValue)
}

final class UnorderedItemListTable: Table {
    static func tableSpec(_ id: Int32) -> ValueBoxTable {
        return ValueBoxTable(id: id, keyType: .binary, compactValuesOnCreation: false)
    }
    
    private func metaInfoKey(tag: UnorderedItemListEntryTag) -> ValueBoxKey {
        let tagValue = tag.value
        let key = ValueBoxKey(length: 1 + tagValue.length)
        key.setUInt8(0, value: UnorderedItemListTableKeyspace.metaInfo.rawValue)
        memcpy(key.memory.advanced(by: 1), tagValue.memory, tagValue.length)
        return key
    }
    
    private func entryKey(tag: UnorderedItemListEntryTag, id: ValueBoxKey) -> ValueBoxKey {
        let tagValue = tag.value
        let key = ValueBoxKey(length: 1 + tagValue.length + id.length)
        key.setUInt8(0, value: UnorderedItemListTableKeyspace.entries.rawValue)
        memcpy(key.memory.advanced(by: 1), tagValue.memory, tagValue.length)
        memcpy(key.memory.advanced(by: 1 + tagValue.length), id.memory, id.length)
        return key
    }
    
    private func entryLowerBoundKey(tag: UnorderedItemListEntryTag) -> ValueBoxKey {
        let tagValue = tag.value
        let key = ValueBoxKey(length: 1 + tagValue.length)
        key.setUInt8(0, value: UnorderedItemListTableKeyspace.entries.rawValue)
        memcpy(key.memory.advanced(by: 1), tagValue.memory, tagValue.length)
        return key
    }
    
    private func entryUpperBoundKey(tag: UnorderedItemListEntryTag) -> ValueBoxKey {
        let tagValue = tag.value.successor
        let key = ValueBoxKey(length: 1 + tagValue.length)
        key.setUInt8(0, value: UnorderedItemListTableKeyspace.entries.rawValue)
        memcpy(key.memory.advanced(by: 1), tagValue.memory, tagValue.length)
        return key
    }
    
    private func getMetaInfo(tag: UnorderedItemListEntryTag) -> UnorderedItemListTagMetaInfo? {
        if let value = self.valueBox.get(self.table, key: self.metaInfoKey(tag: tag)), let info = PostboxDecoder(buffer: value).decodeRootObject() as? UnorderedItemListTagMetaInfo {
            return info
        } else {
            return nil
        }
    }
    
    private func setMetaInfo(tag: UnorderedItemListEntryTag, info: UnorderedItemListTagMetaInfo) {
        let encoder = PostboxEncoder()
        encoder.encodeRootObject(info)
        self.valueBox.set(self.table, key: self.metaInfoKey(tag: tag), value: encoder.readBufferNoCopy())
    }
    
    private func getEntryInfos(tag: UnorderedItemListEntryTag) -> [ValueBoxKey: UnorderedItemListEntryInfo] {
        var result: [ValueBoxKey: UnorderedItemListEntryInfo] = [:]
        let tagLength = tag.value.length
        self.valueBox.range(self.table, start: self.entryLowerBoundKey(tag: tag), end: self.entryUpperBoundKey(tag: tag), values: { key, value in
            result[extractEntryKey(tagLength: tagLength, key: key)] = extractEntryInfo(value)
            return true
        }, limit: 0)
        return result
    }
    
    private func getEntry(tag: UnorderedItemListEntryTag, id: ValueBoxKey) -> UnorderedItemListEntry? {
        if let value = self.valueBox.get(self.table, key: self.entryKey(tag: tag, id: id)) {
            var hashValue: Int64 = 0
            value.read(&hashValue, offset: 0, length: 8)
            let tempBuffer = MemoryBuffer(memory: value.memory.advanced(by: 8), capacity: value.length - 8, length: value.length - 8, freeWhenDone: false)
            let contents = withExtendedLifetime(tempBuffer, {
                return PostboxDecoder(buffer: tempBuffer).decodeRootObject()
            })
            if let contents = contents {
                let entry = UnorderedItemListEntry(id: id, info: UnorderedItemListEntryInfo(hashValue: hashValue), contents: contents)
                return entry
            } else {
                assertionFailure()
                return nil
            }
        } else {
            return nil
        }
    }
    
    private func setEntry(tag: UnorderedItemListEntryTag, entry: UnorderedItemListEntry, sharedBuffer: WriteBuffer, sharedEncoder: PostboxEncoder) {
        sharedBuffer.reset()
        sharedEncoder.reset()
        
        var hashValue: Int64 = entry.info.hashValue
        sharedBuffer.write(&hashValue, offset: 0, length: 8)
        
        sharedEncoder.encodeRootObject(entry.contents)
        let tempBuffer = sharedEncoder.readBufferNoCopy()
        withExtendedLifetime(tempBuffer, {
            sharedBuffer.write(tempBuffer.memory, offset: 0, length: tempBuffer.length)
        })
        
        self.valueBox.set(self.table, key: self.entryKey(tag: tag, id: entry.id), value: sharedBuffer)
    }
    
    func scan(tag: UnorderedItemListEntryTag, _ f: (UnorderedItemListEntry) -> Void) {
        let tagLength = tag.value.length
        self.valueBox.range(self.table, start: self.entryLowerBoundKey(tag: tag), end: self.entryUpperBoundKey(tag: tag), values: { key, value in
            let entryKey = extractEntryKey(tagLength: tagLength, key: key)
            
            var hashValue: Int64 = 0
            value.read(&hashValue, offset: 0, length: 8)
            let tempBuffer = MemoryBuffer(memory: value.memory.advanced(by: 8), capacity: value.length - 8, length: value.length - 8, freeWhenDone: false)
            let contents = withExtendedLifetime(tempBuffer, {
                return PostboxDecoder(buffer: tempBuffer).decodeRootObject()
            })
            if let contents = contents {
                f(UnorderedItemListEntry(id: entryKey, info: UnorderedItemListEntryInfo(hashValue: hashValue), contents: contents))
            } else {
                assertionFailure()
            }
            
            return true
        }, limit: 0)
    }
    
    func difference(tag: UnorderedItemListEntryTag, updatedEntryInfos: [ValueBoxKey: UnorderedItemListEntryInfo]) -> (metaInfo: UnorderedItemListTagMetaInfo?, added: [ValueBoxKey], removed: [UnorderedItemListEntry], updated: [UnorderedItemListEntry]) {
        let currentEntryInfos = self.getEntryInfos(tag: tag)
        var currentInfoIds = Set<ValueBoxKey>()
        for key in currentEntryInfos.keys {
            currentInfoIds.insert(key)
        }
        
        var updatedInfoIds = Set<ValueBoxKey>()
        for key in updatedEntryInfos.keys {
            updatedInfoIds.insert(key)
        }
        
        let addedKeys = updatedInfoIds.subtracting(currentInfoIds)
        let added: [ValueBoxKey] = Array(addedKeys)
        
        let removedKeys = currentInfoIds.subtracting(updatedInfoIds)
        var removed: [UnorderedItemListEntry] = []
        for key in removedKeys {
            if let entry = self.getEntry(tag: tag, id: key) {
                removed.append(entry)
            } else {
                assertionFailure()
            }
        }
        
        var updated: [UnorderedItemListEntry] = []
        for (key, info) in updatedEntryInfos {
            if !addedKeys.contains(key) {
                if let currentInfo = currentEntryInfos[key] {
                    if info.hashValue != currentInfo.hashValue {
                        if let entry = self.getEntry(tag: tag, id: key) {
                            updated.append(entry)
                        } else {
                            assertionFailure()
                        }
                    }
                } else {
                    assertionFailure()
                }
            }
        }
        
        return (self.getMetaInfo(tag: tag), added, removed, updated)
    }
    
    func applyDifference(tag: UnorderedItemListEntryTag, previousInfo: UnorderedItemListTagMetaInfo?, updatedInfo: UnorderedItemListTagMetaInfo, setItems: [UnorderedItemListEntry], removeItemIds: [ValueBoxKey]) -> Bool {
        let currentInfo = self.getMetaInfo(tag: tag)
        if let currentInfo = currentInfo, let previousInfo = previousInfo {
            if !currentInfo.isEqual(to: previousInfo) {
                return false
            }
        } else if (currentInfo != nil) != (previousInfo != nil) {
            return false
        }
        
        self.setMetaInfo(tag: tag, info: updatedInfo)
        
        let sharedBuffer = WriteBuffer()
        let sharedEncoder = PostboxEncoder()
        for entry in setItems {
            self.setEntry(tag: tag, entry: entry, sharedBuffer: sharedBuffer, sharedEncoder: sharedEncoder)
        }
        
        for id in removeItemIds {
            self.valueBox.remove(self.table, key: self.entryKey(tag: tag, id: id), secure: false)
        }
        
        return true
    }
}
