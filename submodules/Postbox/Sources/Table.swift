import Foundation

open class Table {
    public final let valueBox: ValueBox
    public final let table: ValueBoxTable
    
    public init(valueBox: ValueBox, table: ValueBoxTable) {
        self.valueBox = valueBox
        self.table = table
    }
    
    open func clearMemoryCache() {
    }
    
    open func beforeCommit() {
    }
}
