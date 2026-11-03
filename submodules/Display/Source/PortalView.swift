import UIKit
import UIKitRuntimeUtils

public class PortalView {
    public let view: UIView & UIKitPortalViewProtocol
    public weak var sourceView: UIView?
    
    public init?(matchPosition: Bool = true) {
        guard let view = makePortalView(matchPosition) else {
            return nil
        }
        self.view = view
    }
    
    func reloadPortal(sourceView: PortalSourceView) {
        self.view.sourceView = sourceView
        self.sourceView = sourceView
        
        if let portalSuperview = self.view.superview, let index = portalSuperview.subviews.firstIndex(of: self.view) {
            portalSuperview.insertSubview(self.view, at: index)
        } else if let portalSuperlayer = self.view.layer.superlayer, let index = portalSuperlayer.sublayers?.firstIndex(of: self.view.layer) {
            portalSuperlayer.insertSublayer(self.view.layer, at: UInt32(index))
        }
    }
    
    func disablePortal() {
        self.view.sourceView = nil
        self.sourceView = nil
    }
    
    public func reloadPortal() {
        if let sourceView = self.sourceView as? PortalSourceView {
            self.reloadPortal(sourceView: sourceView)
        }
    }
}
