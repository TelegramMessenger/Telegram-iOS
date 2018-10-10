import Foundation

public struct OrderedContactsPeersUpdate {
}

final class MutableOrderedContactsView: MutablePostboxView {
    fileprivate let id: UInt32
    fileprivate var version: Int32 = 0
    
    fileprivate var update: OrderedContactsPeersUpdate?
    
    init(postbox: Postbox) {
        self.id = postbox.takeNextUniqueId()
    }
    
    func replay(postbox: Postbox, transaction: PostboxTransaction) -> Bool {
        var updated = false
        
        if updated {
            self.version += 1
        } else {
            self.update = nil
        }
        return updated
    }
    
    func immutableView() -> PostboxView {
        return OrderedContactsView(self)
    }
}

public final class OrderedContactsView: PostboxView {
    public let id: UInt32
    public let version: Int32
    public let update: OrderedContactsPeersUpdate?
    
    init(_ view: MutableOrderedContactsView) {
        self.id = view.id
        self.version = view.version
        self.update = view.update
    }
}
