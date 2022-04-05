import UIKit

final class GlobalPortalView: PortalView {
    private let wasRemoved: (GlobalPortalView) -> Void
    
    init?(wasRemoved: @escaping (GlobalPortalView) -> Void) {
        self.wasRemoved = wasRemoved
        
        super.init()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func triggerWasRemoved() {
        self.wasRemoved(self)
    }
}
