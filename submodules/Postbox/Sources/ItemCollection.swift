import Foundation

public struct ItemCollectionId: Comparable, Hashable, Codable {
    public typealias Namespace = Int32
    public typealias Id = Int64
    
    public let namespace: ItemCollectionId.Namespace
    public let id: ItemCollectionId.Id
    
    public init(namespace: ItemCollectionId.Namespace, id: ItemCollectionId.Id) {
        self.namespace = namespace
        self.id = id
    }
    
    public static func ==(lhs: ItemCollectionId, rhs: ItemCollectionId) -> Bool {
        return lhs.namespace == rhs.namespace && lhs.id == rhs.id
    }
    
    public static func <(lhs: ItemCollectionId, rhs: ItemCollectionId) -> Bool {
        if lhs.namespace == rhs.namespace {
            return lhs.id < rhs.id
        } else {
            return lhs.namespace < rhs.namespace
        }
    }
    
    public static func encodeArrayToBuffer(_ array: [ItemCollectionId], buffer: WriteBuffer) {
        var length: Int32 = Int32(array.count)
        buffer.write(&length, offset: 0, length: 4)
        for id in array {
            var idNamespace = id.namespace
            buffer.write(&idNamespace, offset: 0, length: 4)
            var idId = id.id
            buffer.write(&idId, offset: 0, length: 8)
        }
    }
    
    public static func decodeArrayFromBuffer(_ buffer: ReadBuffer) -> [ItemCollectionId] {
        var length: Int32 = 0
        memcpy(&length, buffer.memory, 4)
        buffer.offset += 4
        var i = 0
        var array: [ItemCollectionId] = []
        array.reserveCapacity(Int(length))
        while i < Int(length) {
            var idNamespace: Int32 = 0
            buffer.read(&idNamespace, offset: 0, length: 4)
            var idId: Int64 = 0
            buffer.read(&idId, offset: 0, length: 8)
            array.append(ItemCollectionId(namespace: idNamespace, id: idId))
            i += 1
        }
        return array
    }
}

public protocol ItemCollectionInfo: PostboxCoding {
    
}

public struct ItemCollectionItemIndex: Comparable, Hashable {
    public typealias Index = Int32
    public typealias Id = Int64
    
    public let index: ItemCollectionItemIndex.Index
    public let id: ItemCollectionItemIndex.Id
    
    public init(index: ItemCollectionItemIndex.Index, id: ItemCollectionItemIndex.Id) {
        self.index = index
        self.id = id
    }
    
    public static func ==(lhs: ItemCollectionItemIndex, rhs: ItemCollectionItemIndex) -> Bool {
        return lhs.index == rhs.index && lhs.id == rhs.id
    }
    
    public static func <(lhs: ItemCollectionItemIndex, rhs: ItemCollectionItemIndex) -> Bool {
        if lhs.index == rhs.index {
            return lhs.id < rhs.id
        } else {
            return lhs.index < rhs.index
        }
    }
    
    static var lowerBound: ItemCollectionItemIndex {
        return ItemCollectionItemIndex(index: 0, id: 0)
    }
    
    static var upperBound: ItemCollectionItemIndex {
        return ItemCollectionItemIndex(index: Int32.max, id: Int64.max)
    }
}

public protocol ItemCollectionItem: PostboxCoding {
    var index: ItemCollectionItemIndex { get }
    var indexKeys: [MemoryBuffer] { get }
}

public enum ItemCollectionSearchQuery {
    case exact(ValueBoxKey)
    case matching([ValueBoxKey])
    case any([ValueBoxKey])
}
