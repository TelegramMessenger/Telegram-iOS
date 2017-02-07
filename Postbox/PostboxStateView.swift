import Foundation

final class MutablePostboxStateView {
    var state: Coding?
    
    init(state: Coding?) {
        self.state = state
    }
    
    func replay(updatedState: Coding) -> Bool {
        self.state = updatedState
        return true
    }
}

public final class PostboxStateView {
    public let state: Coding?
    
    init(_ view: MutablePostboxStateView) {
        self.state = view.state
    }
}
