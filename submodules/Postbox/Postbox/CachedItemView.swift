import Foundation

final class MutableCachedItemView: MutablePostboxView {
    private let id: ItemCacheEntryId
    fileprivate var value: PostboxCoding?
    
    init(postbox: Postbox, id: ItemCacheEntryId) {
        self.id = id
        self.value = postbox.itemCacheTable.retrieve(id: id, metaTable: postbox.itemCacheMetaTable)
    }
    
    func replay(postbox: Postbox, transaction: PostboxTransaction) -> Bool {
        if transaction.updatedCacheEntryKeys.contains(self.id) {
            self.value = postbox.itemCacheTable.retrieve(id: id, metaTable: postbox.itemCacheMetaTable)
            return true
        }
        return false
    }
    
    func immutableView() -> PostboxView {
        return CachedItemView(self)
    }
}

public final class CachedItemView: PostboxView {
    public let value: PostboxCoding?
    
    init(_ view: MutableCachedItemView) {
        self.value = view.value
    }
}
