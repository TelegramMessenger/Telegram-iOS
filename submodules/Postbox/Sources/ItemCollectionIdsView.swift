import Foundation

final class MutableItemCollectionIdsView: MutablePostboxView {
    let namespaces: [ItemCollectionId.Namespace]
    var idsByNamespace: [ItemCollectionId.Namespace: Set<ItemCollectionId>]
    
    init(postbox: PostboxImpl, namespaces: [ItemCollectionId.Namespace]) {
        self.namespaces = namespaces
        
        var idsByNamespace: [ItemCollectionId.Namespace: Set<ItemCollectionId>] = [:]
        for namespace in namespaces {
            let ids = postbox.itemCollectionInfoTable.getIds(namespace: namespace)
            idsByNamespace[namespace] = Set(ids)
        }
        self.idsByNamespace = idsByNamespace
    }
    
    func replay(postbox: PostboxImpl, transaction: PostboxTransaction) -> Bool {
        if transaction.currentItemCollectionInfosOperations.isEmpty {
            return false
        }
        
        var updated = false
        
        var reloadInfosNamespaces = Set<ItemCollectionId.Namespace>()
        for operation in transaction.currentItemCollectionInfosOperations {
            switch operation {
                case let .replaceInfos(namespace):
                    reloadInfosNamespaces.insert(namespace)
            }
        }
        if !reloadInfosNamespaces.isEmpty {
            for namespace in self.namespaces {
                if reloadInfosNamespaces.contains(namespace) {
                    updated = true
                    let ids = postbox.itemCollectionInfoTable.getIds(namespace: namespace)
                    self.idsByNamespace[namespace] = Set(ids)
                }
            }
        }
        return updated
    }

    func refreshDueToExternalTransaction(postbox: PostboxImpl) -> Bool {
        /*var idsByNamespace: [ItemCollectionId.Namespace: Set<ItemCollectionId>] = [:]
        for namespace in namespaces {
            let ids = postbox.itemCollectionInfoTable.getIds(namespace: namespace)
            idsByNamespace[namespace] = Set(ids)
        }
        if self.idsByNamespace != idsByNamespace {
            self.idsByNamespace = idsByNamespace
            return true
        } else {
            return false
        }*/
        return false
    }
    
    func immutableView() -> PostboxView {
        return ItemCollectionIdsView(self)
    }
}

public final class ItemCollectionIdsView: PostboxView {
    public let idsByNamespace: [ItemCollectionId.Namespace: Set<ItemCollectionId>]
    
    init(_ view: MutableItemCollectionIdsView) {
        self.idsByNamespace = view.idsByNamespace
    }
}
