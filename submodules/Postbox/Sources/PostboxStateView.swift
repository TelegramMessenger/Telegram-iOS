import Foundation

final class MutablePostboxStateView {
    var state: PostboxCoding?
    
    init(state: PostboxCoding?) {
        self.state = state
    }
    
    func replay(updatedState: PostboxCoding) -> Bool {
        self.state = updatedState
        return true
    }
}

public final class PostboxStateView {
    public let state: PostboxCoding?
    
    init(_ view: MutablePostboxStateView) {
        self.state = view.state
    }
}
