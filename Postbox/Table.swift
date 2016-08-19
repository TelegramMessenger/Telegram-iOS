import Foundation

class Table {
    final let valueBox: ValueBox
    final let tableId: Int32
    
    init(valueBox: ValueBox, tableId: Int32) {
        self.valueBox = valueBox
        self.tableId = tableId
    }
    
    func clearMemoryCache() {
    }
    
    func beforeCommit() {
    }
}
