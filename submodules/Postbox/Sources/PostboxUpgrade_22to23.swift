import Foundation

func postboxUpgrade_22to23(metadataTable: MetadataTable, valueBox: ValueBox, progress: (Float) -> Void) {
    postboxLog("Upgrade 22->23 started")
    progress(0.0)
    
    let startTime = CFAbsoluteTimeGetCurrent()
    
    let messageHistoryTable = ValueBoxTable(id: 7, keyType: .binary, compactValuesOnCreation: false)
    let tempMessageHistoryTable = ValueBoxTable(id: 99, keyType: .binary, compactValuesOnCreation: false)
    
    let messageHistoryTagsTable = ValueBoxTable(id: 12, keyType: .binary, compactValuesOnCreation: true)
    let tempMessageHistoryTagsTable = ValueBoxTable(id: 100, keyType: .binary, compactValuesOnCreation: true)
    
    var totalMessageCount = 0
    
    let expectedTotalCount = valueBox.count(messageHistoryTable) + valueBox.count(messageHistoryTagsTable)
    
    let toKey = ValueBoxKey(length: 8 + 4 + 4 + 4)
    
    var messageIndex = -1
    let reportBase = max(1, expectedTotalCount / 100)
    
    postboxLog("Upgrade 22->23 expected to process \(expectedTotalCount) messages")
    
    valueBox.scan(messageHistoryTable, keys: { key in
        totalMessageCount += 1
        
        if messageIndex % reportBase == 0 {
            progress(min(1.0, Float(messageIndex) / Float(expectedTotalCount)))
        }
        messageIndex += 1
        
        toKey.setInt64(0, value: key.getInt64(0))
        toKey.setInt32(8, value: key.getInt32(8 + 4))
        toKey.setInt32(8 + 4, value: key.getInt32(8))
        toKey.setInt32(8 + 4 + 4, value: key.getInt32(8 + 4 + 4))
        
        valueBox.copy(fromTable: messageHistoryTable, fromKey: key, toTable: tempMessageHistoryTable, toKey: toKey)
        return true
    })
    
    let toTagsKey = ValueBoxKey(length: 8 + 4 + 4 + 4 + 4)
    
    valueBox.scan(messageHistoryTagsTable, keys: { key in
        totalMessageCount += 1
        
        if messageIndex % reportBase == 0 {
            progress(min(1.0, Float(messageIndex) / Float(expectedTotalCount)))
        }
        messageIndex += 1
        
        toTagsKey.setInt64(0, value: key.getInt64(0))
        toTagsKey.setUInt32(8, value: key.getUInt32(8))
        toTagsKey.setInt32(8 + 4, value: key.getInt32(8 + 4 + 4))
        toTagsKey.setInt32(8 + 4 + 4, value: key.getInt32(8 + 4))
        toTagsKey.setInt32(8 + 4 + 4 + 4, value: key.getInt32(8 + 4 + 4 + 4))
        
        valueBox.copy(fromTable: messageHistoryTagsTable, fromKey: key, toTable: tempMessageHistoryTagsTable, toKey: toTagsKey)
        return true
    })
    
    valueBox.removeTable(messageHistoryTable)
    valueBox.renameTable(tempMessageHistoryTable, to: messageHistoryTable)
    
    valueBox.removeTable(messageHistoryTagsTable)
    valueBox.renameTable(tempMessageHistoryTagsTable, to: messageHistoryTagsTable)
    
    let endTime = CFAbsoluteTimeGetCurrent()
    postboxLog("Upgrade 22->23 (\(totalMessageCount) messages) took \(endTime - startTime) s")
    
    metadataTable.setUserVersion(23)
    
    progress(1.0)
}
