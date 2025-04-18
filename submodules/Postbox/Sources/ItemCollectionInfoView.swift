import Foundation

final class MutableItemCollectionInfoView: MutablePostboxView {
    let id: ItemCollectionId
    var info: ItemCollectionInfo?
    
    init(postbox: PostboxImpl, id: ItemCollectionId) {
        self.id = id
        let infos = postbox.itemCollectionInfoTable.getInfos(namespace: id.namespace)
        for (_, infoId, info) in infos {
            if id == infoId {
                self.info = info
                break
            }
        }
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
        
        if !reloadInfosNamespaces.isEmpty && reloadInfosNamespaces.contains(self.id.namespace) {
            updated = true
            
            let infos = postbox.itemCollectionInfoTable.getInfos(namespace: id.namespace)
            var found = false
            for (_, infoId, info) in infos {
                if id == infoId {
                    self.info = info
                    found = true
                    break
                }
            }
            if !found {
                self.info = nil
            }
        }
        return updated
    }

    func refreshDueToExternalTransaction(postbox: PostboxImpl) -> Bool {
        return false
    }
    
    func immutableView() -> PostboxView {
        return ItemCollectionInfoView(self)
    }
}

public final class ItemCollectionInfoView: PostboxView {
    public let id: ItemCollectionId
    public let info: ItemCollectionInfo?
    
    init(_ view: MutableItemCollectionInfoView) {
        self.id = view.id
        self.info = view.info
    }
}
