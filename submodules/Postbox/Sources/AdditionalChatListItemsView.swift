import Foundation

final class MutableAdditionalChatListItemsView: MutablePostboxView {
    fileprivate var items: [AdditionalChatListItem]
    
    init(postbox: PostboxImpl) {
        self.items = postbox.additionalChatListItemsTable.get()
    }
    
    func replay(postbox: PostboxImpl, transaction: PostboxTransaction) -> Bool {
        if let items = transaction.replacedAdditionalChatListItems {
            self.items = items
            return true
        }
        return false
    }

    func refreshDueToExternalTransaction(postbox: PostboxImpl) -> Bool {
        return false
    }
    
    func immutableView() -> PostboxView {
        return AdditionalChatListItemsView(self)
    }
}

public final class AdditionalChatListItemsView: PostboxView {
    public let items: [AdditionalChatListItem]
    
    init(_ view: MutableAdditionalChatListItemsView) {
        self.items = view.items
    }
}
