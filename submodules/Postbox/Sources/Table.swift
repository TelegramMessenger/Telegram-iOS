import Foundation

open class Table {
    public final let valueBox: ValueBox
    public final let table: ValueBoxTable
    public final let useCaches: Bool
    
    public init(valueBox: ValueBox, table: ValueBoxTable, useCaches: Bool) {
        self.valueBox = valueBox
        self.table = table
        self.useCaches = useCaches
    }
    
    open func clearMemoryCache() {
    }
    
    open func beforeCommit() {
    }
}
