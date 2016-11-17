import Foundation

class Table {
    final let valueBox: ValueBox
    final let table: ValueBoxTable
    
    init(valueBox: ValueBox, table: ValueBoxTable) {
        self.valueBox = valueBox
        self.table = table
    }
    
    func clearMemoryCache() {
    }
    
    func beforeCommit() {
    }
}
