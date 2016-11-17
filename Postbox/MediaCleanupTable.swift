import Foundation

final class MediaCleanupTable: Table {
    static func tableSpec(_ id: Int32) -> ValueBoxTable {
        return ValueBoxTable(id: id, keyType: .binary)
    }
    
    override init(valueBox: ValueBox, table: ValueBoxTable) {
        super.init(valueBox: valueBox, table: table)
    }
    
    func add(_ media: Media, sharedEncoder: Encoder = Encoder()) {
    }
    
    func debugList() -> [Media] {
        return []
    }
}
