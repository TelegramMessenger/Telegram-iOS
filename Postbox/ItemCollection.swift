import Foundation

public struct ItemCollectionId: Comparable, Hashable {
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
    
    public var hashValue: Int {
        return self.id.hashValue
    }
}

public protocol ItemCollectionInfo: Coding {
    
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
    
    public var hashValue: Int {
        return self.id.hashValue ^ self.index.hashValue
    }
    
    static var lowerBound: ItemCollectionItemIndex {
        return ItemCollectionItemIndex(index: 0, id: 0)
    }
    
    static var upperBound: ItemCollectionItemIndex {
        return ItemCollectionItemIndex(index: Int32.max, id: Int64.max)
    }
}

public protocol ItemCollectionItem: Coding {
    var index: ItemCollectionItemIndex { get }
    var indexKeys: [MemoryBuffer] { get }
}
