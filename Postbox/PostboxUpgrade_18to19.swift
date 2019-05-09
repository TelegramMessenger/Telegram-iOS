import Foundation

private struct PrivatePeerId: Hashable {
    typealias Namespace = Int32
    typealias Id = Int32
    
    let namespace: Namespace
    let id: Id
    
    init(namespace: Namespace, id: Id) {
        self.namespace = namespace
        self.id = id
    }
    
    init(_ n: Int64) {
        self.namespace = Int32((n >> 32) & 0x7fffffff)
        self.id = Int32(bitPattern: UInt32(n & 0xffffffff))
    }
    
    func toInt64() -> Int64 {
        return (Int64(self.namespace) << 32) | Int64(bitPattern: UInt64(UInt32(bitPattern: self.id)))
    }
}

func postboxUpgrade_18to19(metadataTable: MetadataTable, valueBox: ValueBox, progress: (Float) -> Void) {
    postboxLog("Upgrade 18->19 started")
    progress(0.0)
    
    let startTime = CFAbsoluteTimeGetCurrent()
    
    let globalMessageIdsTable = ValueBoxTable(id: 3, keyType: .int64, compactValuesOnCreation: false)
    let messageHistoryIndexTable = ValueBoxTable(id: 4, keyType: .binary, compactValuesOnCreation: true)
    
    valueBox.removeAllFromTable(globalMessageIdsTable)
    
    let absoluteLowerBound = ValueBoxKey(length: 8)
    absoluteLowerBound.setInt64(0, value: 0)
    
    let absoluteUpperBound = ValueBoxKey(length: 8)
    absoluteUpperBound.setInt64(0, value: Int64.max - 1)
    
    let sharedGlobalIdsKey = ValueBoxKey(length: 8)
    let sharedGlobalIdsBuffer = WriteBuffer()
    
    var totalMessageCount = 0
    
    let expectedTotalCount = valueBox.count(messageHistoryIndexTable)
    var messageIndex = -1
    let reportBase = max(1, expectedTotalCount / 100)
    
    let currentLowerBound: ValueBoxKey = absoluteLowerBound
    while true {
        var currentPeerId: PrivatePeerId?
        valueBox.range(messageHistoryIndexTable, start: currentLowerBound, end: absoluteUpperBound, keys: {
            key in
            currentPeerId = PrivatePeerId(key.getInt64(0))
            return true
        }, limit: 1)
        if let currentPeerId = currentPeerId {
            /*assert(!checkPeerIds.contains(currentPeerId))
            checkPeerIds.insert(currentPeerId)*/
            
            if currentPeerId.namespace == 0 || currentPeerId.namespace == 1 { // CloudUser || CloudGroup
                let peerCloudLowerBound = ValueBoxKey(length: 8 + 4)
                peerCloudLowerBound.setInt64(0, value: currentPeerId.toInt64())
                peerCloudLowerBound.setInt32(8, value: 0) // Cloud
                
                let sharedIdPeerId = currentPeerId.toInt64()
                
                valueBox.range(messageHistoryIndexTable, start: peerCloudLowerBound, end: peerCloudLowerBound.successor, values: { key, value in
                    //assert(key.getInt64(0) == currentPeerId.toInt64())
                    //assert(key.getInt32(8) == 0)
                    
                    totalMessageCount += 1
                    
                    if messageIndex % reportBase == 0 {
                        progress(min(1.0, Float(messageIndex) / Float(expectedTotalCount)))
                    }
                    messageIndex += 1
                    
                    let HistoryEntryTypeMask: Int8 = 1
                    let HistoryEntryTypeMessage: Int8 = 0
                    
                    var flags: Int8 = 0
                    value.read(&flags, offset: 0, length: 1)
                    
                    if (flags & HistoryEntryTypeMask) == HistoryEntryTypeMessage {
                        let id = key.getInt32(8 + 4)
                        
                        /*let res = checkMessageIds.insert(MessageId(peerId: PeerId(currentPeerId.toInt64()), namespace: 0, id: id))
                        assert(res.inserted)*/
                        
                        sharedGlobalIdsKey.setInt64(0, value: Int64(id))
                        
                        sharedGlobalIdsBuffer.reset()
                        var idPeerId: Int64 = sharedIdPeerId
                        var idNamespace: Int32 = 0
                        sharedGlobalIdsBuffer.write(&idPeerId, offset: 0, length: 8)
                        sharedGlobalIdsBuffer.write(&idNamespace, offset: 0, length: 4)
                        
                        valueBox.set(globalMessageIdsTable, key: sharedGlobalIdsKey, value: sharedGlobalIdsBuffer)
                    }
                    return true
                }, limit: 0)
            }
            currentLowerBound.setInt64(0, value: currentPeerId.toInt64() + 1)
            currentLowerBound.setInt32(8, value: 0)
            currentLowerBound.setInt32(8 + 4, value: 0)
        } else {
            break
        }
    }
    
    /*assert(debugPeerIds == checkPeerIds)
    assert(debugMessageIds == checkMessageIds)*/
    
    let endTime = CFAbsoluteTimeGetCurrent()
    postboxLog("Upgrade 18->19 (\(totalMessageCount) messages) took \(endTime - startTime) s")
    
    metadataTable.setUserVersion(19)
}
