import Foundation
import Display

public protocol OverlayMediaController: class {
    var hasNodes: Bool { get }
    func addNode(_ node: OverlayMediaItemNode, customTransition: Bool)
    func removeNode(_ node: OverlayMediaItemNode, customTransition: Bool)
}

public final class OverlayMediaManager {
    public var controller: (OverlayMediaController & ViewController)?
    
    public init() {
    }
    
    public func attachOverlayMediaController(_ controller: OverlayMediaController & ViewController) {
        self.controller = controller
    }
}
