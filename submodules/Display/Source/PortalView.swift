import UIKit
import UIKitRuntimeUtils

public class PortalView {
    public let view: UIView & UIKitPortalViewProtocol
    
    public init?() {
        guard let view = makePortalView() else {
            return nil
        }
        self.view = view
    }
    
    func reloadPortal(sourceView: PortalSourceView) {
        self.view.sourceView = sourceView
        
        if let portalSuperview = self.view.superview, let index = portalSuperview.subviews.firstIndex(of: self.view) {
            portalSuperview.insertSubview(self.view, at: index)
        }
    }
}
