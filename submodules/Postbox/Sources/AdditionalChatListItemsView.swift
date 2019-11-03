import Foundation

final class MutableAdditionalChatListItemsView: MutablePostboxView {
    fileprivate var items: Set<PeerId>
    
    init(postbox: Postbox) {
        self.items = Set(postbox.additionalChatListItemsTable.get())
    }
    
    func replay(postbox: Postbox, transaction: PostboxTransaction) -> Bool {
        if let items = transaction.replacedAdditionalChatListItems {
            self.items = Set(items)
            return true
        }
        return false
    }
    
    func immutableView() -> PostboxView {
        return AdditionalChatListItemsView(self)
    }
}

public final class AdditionalChatListItemsView: PostboxView {
    public let items: Set<PeerId>
    
    init(_ view: MutableAdditionalChatListItemsView) {
        self.items = view.items
    }
}
