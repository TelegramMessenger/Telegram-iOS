import Foundation

public struct ItemCollectionViewEntryIndex: Comparable {
    public let collectionIndex: Int32
    public let collectionId: ItemCollectionId
    public let itemIndex: ItemCollectionItemIndex
    
    public init(collectionIndex: Int32, collectionId: ItemCollectionId, itemIndex: ItemCollectionItemIndex) {
        self.collectionIndex = collectionIndex
        self.collectionId = collectionId
        self.itemIndex = itemIndex
    }
    
    public static func ==(lhs: ItemCollectionViewEntryIndex, rhs: ItemCollectionViewEntryIndex) -> Bool {
        return lhs.collectionIndex == rhs.collectionIndex && lhs.collectionId == rhs.collectionId && lhs.itemIndex == rhs.itemIndex
    }
    
    public static func <(lhs: ItemCollectionViewEntryIndex, rhs: ItemCollectionViewEntryIndex) -> Bool {
        if lhs.collectionIndex == rhs.collectionIndex {
            if lhs.itemIndex == rhs.itemIndex {
                return lhs.collectionId < rhs.collectionId
            } else {
                return lhs.itemIndex < rhs.itemIndex
            }
        } else {
            return lhs.collectionIndex < rhs.collectionIndex
        }
    }
    
    public static func lowerBound(collectionIndex: Int32, collectionId: ItemCollectionId) -> ItemCollectionViewEntryIndex {
        return ItemCollectionViewEntryIndex(collectionIndex: collectionIndex, collectionId: collectionId, itemIndex: ItemCollectionItemIndex(index: 0, id: 0))
    }
}

public struct ItemCollectionViewEntry {
    public let index: ItemCollectionViewEntryIndex
    public let item: ItemCollectionItem
}

private func fetchLowerEntries(namespaces: [ItemCollectionId.Namespace], collectionId: ItemCollectionId, collectionIndex: Int32, itemIndex: ItemCollectionItemIndex, count: Int, lowerCollectionId: (_ namespaceList: [ItemCollectionId.Namespace], _ collectionId: ItemCollectionId, _ collectionIndex: Int32) -> (ItemCollectionId, Int32)?, lowerItems: (_ collectionId: ItemCollectionId, _ itemIndex: ItemCollectionItemIndex, _ count: Int) -> [ItemCollectionItem]) -> [ItemCollectionViewEntry] {
    
    var entries: [ItemCollectionViewEntry] = []
    
    var currentCollectionIndex = collectionIndex
    var currentCollectionId = collectionId
    var currentItemIndex = itemIndex
    
    while true {
        let remainingCount = count - entries.count
        assert(remainingCount > 0)
        let collectionItems = lowerItems(currentCollectionId, currentItemIndex, remainingCount)
        for item in collectionItems {
            entries.append(ItemCollectionViewEntry(index: ItemCollectionViewEntryIndex(collectionIndex: currentCollectionIndex, collectionId: currentCollectionId, itemIndex: item.index), item: item))
        }
        if entries.count >= count {
            break
        } else {
            assert(collectionItems.count < remainingCount)
            
            if let (previousCollectionId, previousCollectionIndex) = lowerCollectionId(namespaces, currentCollectionId, currentCollectionIndex) {
                currentCollectionIndex = previousCollectionIndex
                currentCollectionId = previousCollectionId
                currentItemIndex = ItemCollectionItemIndex.upperBound
            } else {
                break
            }
        }
    }
    
    return entries
}

private func fetchHigherEntries(namespaces: [ItemCollectionId.Namespace], collectionId: ItemCollectionId, collectionIndex: Int32, itemIndex: ItemCollectionItemIndex, count: Int, higherCollectionId: (_ namespaceList: [ItemCollectionId.Namespace], _ collectionId: ItemCollectionId, _ collectionIndex: Int32) -> (ItemCollectionId, Int32)?, higherItems: (_ collectionId: ItemCollectionId, _ itemIndex: ItemCollectionItemIndex, _ count: Int) -> [ItemCollectionItem]) -> [ItemCollectionViewEntry] {
    
    var entries: [ItemCollectionViewEntry] = []
    
    var currentCollectionIndex = collectionIndex
    var currentCollectionId = collectionId
    var currentItemIndex = itemIndex
    
    while true {
        let remainingCount = count - entries.count
        assert(remainingCount > 0)
        let collectionItems = higherItems(currentCollectionId, currentItemIndex, remainingCount)
        for item in collectionItems {
            entries.append(ItemCollectionViewEntry(index: ItemCollectionViewEntryIndex(collectionIndex: currentCollectionIndex, collectionId: currentCollectionId, itemIndex: item.index), item: item))
        }
        if entries.count >= count {
            break
        } else {
            assert(collectionItems.count < remainingCount)
            
            if let (nextCollectionId, nextCollectionIndex) = higherCollectionId(namespaces, currentCollectionId, currentCollectionIndex) {
                currentCollectionIndex = nextCollectionIndex
                currentCollectionId = nextCollectionId
                currentItemIndex = ItemCollectionItemIndex.lowerBound
            } else {
                break
            }
        }
    }
    
    return entries
}

private func aroundEntries(namespaces: [ItemCollectionId.Namespace],
                           collectionId: ItemCollectionId,
                           collectionIndex: Int32,
                           itemIndex: ItemCollectionItemIndex,
                           count: Int,
                           lowerCollectionId: (_ namespaceList: [ItemCollectionId.Namespace], _ collectionId: ItemCollectionId, _ collectionIndex: Int32) -> (ItemCollectionId, Int32)?,
                           fetchLowerItems: (_ collectionId: ItemCollectionId, _ itemIndex: ItemCollectionItemIndex, _ count: Int) -> [ItemCollectionItem],
                           higherCollectionId: (_ namespaceList: [ItemCollectionId.Namespace], _ collectionId: ItemCollectionId, _ collectionIndex: Int32) -> (ItemCollectionId, Int32)?,
                           fetchHigherItems: (_ collectionId: ItemCollectionId, _ itemIndex: ItemCollectionItemIndex, _ count: Int) -> [ItemCollectionItem]) -> ([ItemCollectionViewEntry], ItemCollectionViewEntry?, ItemCollectionViewEntry?) {
    var lowerEntries: [ItemCollectionViewEntry] = []
    var upperEntries: [ItemCollectionViewEntry] = []
    var lower: ItemCollectionViewEntry?
    var upper: ItemCollectionViewEntry?
    
    lowerEntries.append(contentsOf: fetchLowerEntries(namespaces: namespaces, collectionId: collectionId, collectionIndex: collectionIndex, itemIndex: itemIndex, count: count / 2 + 1, lowerCollectionId: lowerCollectionId, lowerItems: fetchLowerItems))
    
    let lowerIndices = lowerEntries.map { $0.index }
    assert(lowerIndices.sorted() == lowerIndices.reversed())
    
    if lowerEntries.count >= count / 2 + 1 {
        lower = lowerEntries.last
        lowerEntries.removeLast()
    }
    
    upperEntries.append(contentsOf: fetchHigherEntries(namespaces: namespaces, collectionId: collectionId, collectionIndex: collectionIndex, itemIndex: ItemCollectionItemIndex(index: itemIndex.index, id: max(0, itemIndex.id - 1)), count: count - lowerEntries.count + 1, higherCollectionId: higherCollectionId, higherItems: fetchHigherItems))
    
    let upperIndices = upperEntries.map { $0.index }
    assert(upperIndices.sorted() == upperIndices)
    
    if upperEntries.count >= count - lowerEntries.count + 1 {
        upper = upperEntries.last
        upperEntries.removeLast()
    }
    
    if lowerEntries.count != 0 && lowerEntries.count + upperEntries.count < count {
        var additionalLowerEntries: [ItemCollectionViewEntry] = fetchLowerEntries(namespaces: namespaces, collectionId: lowerEntries.last!.index.collectionId, collectionIndex: lowerEntries.last!.index.collectionIndex, itemIndex: lowerEntries.last!.index.itemIndex, count: count - lowerEntries.count - upperEntries.count + 1, lowerCollectionId: lowerCollectionId, lowerItems: fetchLowerItems)
        
        if additionalLowerEntries.count >= count - lowerEntries.count + upperEntries.count + 1 {
            lower = additionalLowerEntries.last
            additionalLowerEntries.removeLast()
        }
        lowerEntries.append(contentsOf: additionalLowerEntries)
    }
    
    var entries: [ItemCollectionViewEntry] = []
    entries.append(contentsOf: lowerEntries.reversed())
    entries.append(contentsOf: upperEntries)
    return (entries: entries, lower: lower, upper: upper)
}

final class MutableItemCollectionsView {
    let orderedItemListsViews: [MutableOrderedItemListView]
    let namespaces: [ItemCollectionId.Namespace]
    
    var collectionInfos: [(ItemCollectionId, ItemCollectionInfo, ItemCollectionItem?)]
    var entries: [ItemCollectionViewEntry]
    var lower: ItemCollectionViewEntry?
    var higher: ItemCollectionViewEntry?
    
    init(orderedItemListsViews: [MutableOrderedItemListView], namespaces: [ItemCollectionId.Namespace], aroundIndex: ItemCollectionViewEntryIndex?, count: Int, getInfos: (_ namespace: ItemCollectionId.Namespace) -> [(Int, ItemCollectionId, ItemCollectionInfo)], lowerCollectionId: (_ namespaceList: [ItemCollectionId.Namespace], _ collectionId: ItemCollectionId, _ collectionIndex: Int32) -> (ItemCollectionId, Int32)?, lowerItems: (_ collectionId: ItemCollectionId, _ itemIndex: ItemCollectionItemIndex, _ count: Int) -> [ItemCollectionItem], higherCollectionId: (_ namespaceList: [ItemCollectionId.Namespace], _ collectionId: ItemCollectionId, _ collectionIndex: Int32) -> (ItemCollectionId, Int32)?, higherItems: (_ collectionId: ItemCollectionId, _ itemIndex: ItemCollectionItemIndex, _ count: Int) -> [ItemCollectionItem]) {
        self.orderedItemListsViews = orderedItemListsViews
        self.namespaces = namespaces
        
        self.collectionInfos = []
        for namespace in namespaces {
            for (_, id, info) in getInfos(namespace) {
                let item = higherItems(id, ItemCollectionItemIndex.lowerBound, 1).first
                self.collectionInfos.append((id, info, item))
            }
        }
        
        let selectedAroundIndex: ItemCollectionViewEntryIndex
        if let aroundIndex = aroundIndex {
            selectedAroundIndex = aroundIndex
        } else {
            selectedAroundIndex = ItemCollectionViewEntryIndex(collectionIndex: 0, collectionId: ItemCollectionId(namespace: namespaces[0], id: 0), itemIndex: ItemCollectionItemIndex.lowerBound)
        }
        
        let (entries, lower, higher) = aroundEntries(namespaces: namespaces,
            collectionId: selectedAroundIndex.collectionId,
            collectionIndex: selectedAroundIndex.collectionIndex,
            itemIndex: selectedAroundIndex.itemIndex,
            count: count,
            lowerCollectionId: lowerCollectionId,
            fetchLowerItems: lowerItems,
            higherCollectionId: higherCollectionId,
            fetchHigherItems: higherItems)
        
        self.entries = entries
        self.lower = lower
        self.higher = higher
    }
    
    func replay(orderedItemListOperations: [Int32: [OrderedItemListOperation]]) -> Bool {
        var updated = false
        for view in self.orderedItemListsViews {
            if view.replay(operations: orderedItemListOperations) {
                updated = true
            }
        }
        return updated
    }
}

public final class ItemCollectionsView {
    public let orderedItemListsViews: [OrderedItemListView]
    public let collectionInfos: [(ItemCollectionId, ItemCollectionInfo, ItemCollectionItem?)]
    public let entries: [ItemCollectionViewEntry]
    public let lower: ItemCollectionViewEntry?
    public let higher: ItemCollectionViewEntry?
    
    init(_ mutableView: MutableItemCollectionsView) {
        self.orderedItemListsViews = mutableView.orderedItemListsViews.map { OrderedItemListView($0) }
        self.collectionInfos = mutableView.collectionInfos
        self.entries = mutableView.entries
        self.lower = mutableView.lower
        self.higher = mutableView.higher
    }
}
