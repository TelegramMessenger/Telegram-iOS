import Foundation

public final class ItemCollectionInfoEntry {
    public let id: ItemCollectionId
    public let info: ItemCollectionInfo
    public let count: Int32
    public let firstItem: ItemCollectionItem?
    
    init(id: ItemCollectionId, info: ItemCollectionInfo, count: Int32, firstItem: ItemCollectionItem?) {
        self.id = id
        self.info = info
        self.count = count
        self.firstItem = firstItem
    }
}

final class MutableItemCollectionInfosView: MutablePostboxView {
    let namespaces: [ItemCollectionId.Namespace]
    var entriesByNamespace: [ItemCollectionId.Namespace: [ItemCollectionInfoEntry]]
    
    init(postbox: PostboxImpl, namespaces: [ItemCollectionId.Namespace]) {
        self.namespaces = namespaces
        
        var entriesByNamespace: [ItemCollectionId.Namespace: [ItemCollectionInfoEntry]] = [:]
        for namespace in namespaces {
            let infos = postbox.itemCollectionInfoTable.getInfos(namespace: namespace)
            var entries: [ItemCollectionInfoEntry] = []
            for (_, id, info) in infos {
                let firstItem = postbox.itemCollectionItemTable.higherItems(collectionId: id, itemIndex: ItemCollectionItemIndex.lowerBound, count: 1).first
                entries.append(ItemCollectionInfoEntry(id: id, info: info, count: postbox.itemCollectionItemTable.itemCount(collectionId: id), firstItem: firstItem))
            }
            entriesByNamespace[namespace] = entries
        }
        self.entriesByNamespace = entriesByNamespace
    }
    
    func replay(postbox: PostboxImpl, transaction: PostboxTransaction) -> Bool {
        if transaction.currentItemCollectionInfosOperations.isEmpty && transaction.currentItemCollectionItemsOperations.isEmpty {
            return false
        }
        
        var updated = false
        
        var reloadInfosNamespaces = Set<ItemCollectionId.Namespace>()
        var reloadTopItemCollectionIds = Set<ItemCollectionId>()
        for operation in transaction.currentItemCollectionInfosOperations {
            switch operation {
                case let .replaceInfos(namespace):
                    reloadInfosNamespaces.insert(namespace)
            }
        }
        for (id, operations) in transaction.currentItemCollectionItemsOperations {
            for operation in operations {
                switch operation {
                    case .replaceItems:
                        reloadTopItemCollectionIds.insert(id)
                }
            }
        }
        if !reloadInfosNamespaces.isEmpty {
            updated = true
            
            var entriesByNamespace: [ItemCollectionId.Namespace: [ItemCollectionInfoEntry]] = [:]
            for namespace in self.namespaces {
                let infos = postbox.itemCollectionInfoTable.getInfos(namespace: namespace)
                var entries: [ItemCollectionInfoEntry] = []
                for (_, id, info) in infos {
                    let firstItem = postbox.itemCollectionItemTable.higherItems(collectionId: id, itemIndex: ItemCollectionItemIndex.lowerBound, count: 1).first
                    entries.append(ItemCollectionInfoEntry(id: id, info: info, count: postbox.itemCollectionItemTable.itemCount(collectionId: id), firstItem: firstItem))
                }
                entriesByNamespace[namespace] = entries
            }
            self.entriesByNamespace = entriesByNamespace
        } else if !reloadTopItemCollectionIds.isEmpty {
            var entriesByNamespace = self.entriesByNamespace
            for (namespace, entries) in self.entriesByNamespace {
                var items: [ItemCollectionInfoEntry] = []
                for i in 0 ..< entries.count {
                    if reloadTopItemCollectionIds.contains(entries[i].id) {
                        updated = true
                        let firstItem = postbox.itemCollectionItemTable.higherItems(collectionId: entries[i].id, itemIndex: ItemCollectionItemIndex.lowerBound, count: 1).first
                        items.append(ItemCollectionInfoEntry(id: entries[i].id, info: entries[i].info, count: postbox.itemCollectionItemTable.itemCount(collectionId: entries[i].id), firstItem: firstItem))
                    } else {
                        items.append(entriesByNamespace[namespace]![i])
                    }
                }
                entriesByNamespace[namespace] = items
            }
            self.entriesByNamespace = entriesByNamespace
        }
        return updated
    }

    func refreshDueToExternalTransaction(postbox: PostboxImpl) -> Bool {
        return false
    }
    
    func immutableView() -> PostboxView {
        return ItemCollectionInfosView(self)
    }
}

public final class ItemCollectionInfosView: PostboxView {
    public let entriesByNamespace: [ItemCollectionId.Namespace: [ItemCollectionInfoEntry]]
    
    init(_ view: MutableItemCollectionInfosView) {
        self.entriesByNamespace = view.entriesByNamespace
    }
}
