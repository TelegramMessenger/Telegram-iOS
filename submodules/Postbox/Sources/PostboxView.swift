import Foundation

public protocol PostboxView {
}

protocol MutablePostboxView {
    func replay(postbox: PostboxImpl, transaction: PostboxTransaction) -> Bool
    func refreshDueToExternalTransaction(postbox: PostboxImpl) -> Bool
    func immutableView() -> PostboxView
}

final class CombinedMutableView {
    private let views: [PostboxViewKey: MutablePostboxView]
    
    init(views: [PostboxViewKey: MutablePostboxView]) {
        self.views = views
    }
    
    func replay(postbox: PostboxImpl, transaction: PostboxTransaction) -> Bool {
        var updated = false
        for (_, view) in self.views {
            if view.replay(postbox: postbox, transaction: transaction) {
                updated = true
            }
        }
        return updated
    }

    func refreshDueToExternalTransaction(postbox: PostboxImpl) -> Bool {
        var updated = false
        for (_, view) in self.views {
            if view.refreshDueToExternalTransaction(postbox: postbox) {
                updated = true
            }
        }
        return updated
    }
    
    func immutableView() -> CombinedView {
        var result: [PostboxViewKey: PostboxView] = [:]
        for (key, view) in self.views {
            result[key] = view.immutableView()
        }
        return CombinedView(views: result)
    }
}

public final class CombinedView {
    public let views: [PostboxViewKey: PostboxView]
    
    init(views: [PostboxViewKey: PostboxView]) {
        self.views = views
    }
}
