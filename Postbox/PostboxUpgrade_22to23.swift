import Foundation

func postboxUpgrade_22to23(metadataTable: MetadataTable, valueBox: ValueBox, progress: (Float) -> Void) {
    progress(0.0)
    
    let startTime = CFAbsoluteTimeGetCurrent()
    
    let messageHistoryTable = ValueBoxTable(id: 7, keyType: .binary, compactValuesOnCreation: false)
    let tempMessageHistoryTable = ValueBoxTable(id: 99, keyType: .binary, compactValuesOnCreation: false)
    
    var totalMessageCount = 0
    
    let expectedTotalCount = valueBox.count(messageHistoryTable)
    
    let toKey = ValueBoxKey(length: 8 + 4 + 4 + 4)
    
    var messageIndex = -1
    let reportBase = max(1, expectedTotalCount / 100)
    
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
    
    valueBox.removeTable(messageHistoryTable)
    valueBox.renameTable(tempMessageHistoryTable, to: messageHistoryTable)
    
    let endTime = CFAbsoluteTimeGetCurrent()
    postboxLog("Upgrade 22->23 (\(totalMessageCount) messages) took \(endTime - startTime) s")
    
    metadataTable.setUserVersion(23)
    
    progress(1.0)
}
