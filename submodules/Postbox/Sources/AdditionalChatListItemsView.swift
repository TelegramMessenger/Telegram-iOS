import Foundation

final class MutableAdditionalChatListItemsView: MutablePostboxView {
    fileprivate var items: [AdditionalChatListItem]
    
    init(postbox: Postbox) {
        self.items = postbox.additionalChatListItemsTable.get()
    }
    
    func replay(postbox: Postbox, transaction: PostboxTransaction) -> Bool {
        if let items = transaction.replacedAdditionalChatListItems {
            self.items = items
            return true
        }
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
