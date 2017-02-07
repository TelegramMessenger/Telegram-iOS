import Foundation

public protocol OrderedItemListEntryContents: Coding {
    
}

public struct OrderedItemListEntry {
    public let id: MemoryBuffer
    public let contents: OrderedItemListEntryContents
    
    public init(id: MemoryBuffer, contents: OrderedItemListEntryContents) {
        self.id = id
        self.contents = contents
    }
}
