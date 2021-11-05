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
    
    public init(index: ItemCollectionViewEntryIndex, item: ItemCollectionItem) {
        self.index = index
        self.item = item
    }
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
                           aroundIndex: ItemCollectionViewEntryIndex?,
                           count: Int,
                           collectionIndexById: (ItemCollectionId) -> Int32?,
                           lowerCollectionId: (_ namespaceList: [ItemCollectionId.Namespace], _ collectionId: ItemCollectionId, _ collectionIndex: Int32) -> (ItemCollectionId, Int32)?,
                           fetchLowerItems: (_ collectionId: ItemCollectionId, _ itemIndex: ItemCollectionItemIndex, _ count: Int) -> [ItemCollectionItem],
                           higherCollectionId: (_ namespaceList: [ItemCollectionId.Namespace], _ collectionId: ItemCollectionId, _ collectionIndex: Int32) -> (ItemCollectionId, Int32)?,
                           fetchHigherItems: (_ collectionId: ItemCollectionId, _ itemIndex: ItemCollectionItemIndex, _ count: Int) -> [ItemCollectionItem]) -> ([ItemCollectionViewEntry], ItemCollectionViewEntry?, ItemCollectionViewEntry?) {
    var lowerEntries: [ItemCollectionViewEntry] = []
    var upperEntries: [ItemCollectionViewEntry] = []
    var lower: ItemCollectionViewEntry?
    var upper: ItemCollectionViewEntry?
    
    let selectedAroundIndex: ItemCollectionViewEntryIndex
    if let aroundIndex = aroundIndex, let aroundCollectionIndex = collectionIndexById(aroundIndex.collectionId) {
        selectedAroundIndex = ItemCollectionViewEntryIndex(collectionIndex: aroundCollectionIndex, collectionId: aroundIndex.collectionId, itemIndex: aroundIndex.itemIndex)
    } else {
        selectedAroundIndex = ItemCollectionViewEntryIndex(collectionIndex: 0, collectionId: ItemCollectionId(namespace: namespaces[0], id: 0), itemIndex: ItemCollectionItemIndex.lowerBound)
    }
    
    let collectionId: ItemCollectionId = selectedAroundIndex.collectionId
    let collectionIndex: Int32 = selectedAroundIndex.collectionIndex
    let itemIndex: ItemCollectionItemIndex = selectedAroundIndex.itemIndex
    
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
    let requestedAroundIndex: ItemCollectionViewEntryIndex?
    let requestedCount: Int
    
    var collectionInfos: [(ItemCollectionId, ItemCollectionInfo, ItemCollectionItem?)]
    var entries: [ItemCollectionViewEntry]
    var lower: ItemCollectionViewEntry?
    var higher: ItemCollectionViewEntry?
    
    init(postbox: PostboxImpl, orderedItemListsViews: [MutableOrderedItemListView], namespaces: [ItemCollectionId.Namespace], aroundIndex: ItemCollectionViewEntryIndex?, count: Int) {
        self.orderedItemListsViews = orderedItemListsViews
        self.namespaces = namespaces
        self.requestedAroundIndex = aroundIndex
        self.requestedCount = count
        
        self.collectionInfos = []
        self.entries = []
        self.lower = nil
        self.higher = nil
        
        self.reload(postbox: postbox, aroundIndex: aroundIndex, count: count)
    }
    
    private func lowerItems(postbox: PostboxImpl, collectionId: ItemCollectionId, itemIndex: ItemCollectionItemIndex, count: Int) -> [ItemCollectionItem] {
        return postbox.itemCollectionItemTable.lowerItems(collectionId: collectionId, itemIndex: itemIndex, count: count)
    }
    
    private func higherItems(postbox: PostboxImpl, collectionId: ItemCollectionId, itemIndex: ItemCollectionItemIndex, count: Int) -> [ItemCollectionItem] {
        return postbox.itemCollectionItemTable.higherItems(collectionId: collectionId, itemIndex: itemIndex, count: count)
    }
    
    private func lowerCollectionId(postbox: PostboxImpl, namespaceList: [ItemCollectionId.Namespace], collectionId: ItemCollectionId, collectionIndex: Int32) -> (ItemCollectionId, Int32)? {
        return postbox.itemCollectionInfoTable.lowerCollectionId(namespaceList: namespaceList, collectionId: collectionId, index: collectionIndex)
    }
    
    private func higherCollectionId(postbox: PostboxImpl, namespaceList: [ItemCollectionId.Namespace], collectionId: ItemCollectionId, collectionIndex: Int32) -> (ItemCollectionId, Int32)? {
        return postbox.itemCollectionInfoTable.higherCollectionId(namespaceList: namespaceList, collectionId: collectionId, index: collectionIndex)
    }
    
    private func reload(postbox: PostboxImpl, aroundIndex: ItemCollectionViewEntryIndex?, count: Int) {
        self.collectionInfos = []
        for namespace in namespaces {
            for (_, id, info) in postbox.itemCollectionInfoTable.getInfos(namespace: namespace) {
                let item = self.higherItems(postbox: postbox, collectionId: id, itemIndex: ItemCollectionItemIndex.lowerBound, count: 1).first
                self.collectionInfos.append((id, info, item))
            }
        }
        
        let (entries, lower, higher) = aroundEntries(namespaces: namespaces,
                                                     aroundIndex: aroundIndex,
                                                     count: count, collectionIndexById: { id in
                                                        return postbox.itemCollectionInfoTable.getIndex(id: id)
        },
                                                     lowerCollectionId: { namespaceList, collectionId, collectionIndex in
                                                        return self.lowerCollectionId(postbox: postbox, namespaceList: namespaceList, collectionId: collectionId, collectionIndex: collectionIndex)
        },
                                                     fetchLowerItems: { collectionId, itemIndex, count in
                                                        return self.lowerItems(postbox: postbox, collectionId: collectionId, itemIndex: itemIndex, count: count)
        },
                                                     higherCollectionId: { namespaceList, collectionId, collectionIndex in
                                                        return self.higherCollectionId(postbox: postbox, namespaceList: namespaceList, collectionId: collectionId, collectionIndex: collectionIndex)
        },
                                                     fetchHigherItems: {
                                                        collectionId, itemIndex, count in
                                                        return self.higherItems(postbox: postbox, collectionId: collectionId, itemIndex: itemIndex, count: count)
        })
        
        self.entries = entries
        self.lower = lower
        self.higher = higher
    }
    
    func replay(postbox: PostboxImpl, transaction: PostboxTransaction) -> Bool {
        var updated = false
        
        if !transaction.currentOrderedItemListOperations.isEmpty {
            for view in self.orderedItemListsViews {
                if view.replay(postbox: postbox, transaction: transaction) {
                    updated = true
                }
            }
        }
        
        
        var reloadNamespaces = Set<ItemCollectionId.Namespace>()
        for operation in transaction.currentItemCollectionInfosOperations {
            switch operation {
                case let .replaceInfos(namespace):
                    reloadNamespaces.insert(namespace)
            }
        }
        
        for (id, operations) in transaction.currentItemCollectionItemsOperations {
            for operation in operations {
                switch operation {
                    case .replaceItems:
                        reloadNamespaces.insert(id.namespace)
                }
            }
        }
        
        var shouldReloadEntries = false
        if !reloadNamespaces.isEmpty {
            for namespace in self.namespaces {
                if reloadNamespaces.contains(namespace) {
                    shouldReloadEntries = true
                    break
                }
            }
        }
        
        if shouldReloadEntries {
            self.reload(postbox: postbox, aroundIndex: self.requestedAroundIndex, count: self.requestedCount)
            updated = true
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
