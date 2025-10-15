import Foundation

public struct OrderedItemListEntry {
    public let id: MemoryBuffer
    public let contents: CodableEntry
    
    public init(id: MemoryBuffer, contents: CodableEntry) {
        self.id = id
        self.contents = contents
    }
}
