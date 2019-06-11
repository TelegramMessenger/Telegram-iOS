import Foundation

public final class OverlayMediaManager {
    public var controller: OverlayMediaController?
    
    public func attachOverlayMediaController(_ controller: OverlayMediaController) {
        self.controller = controller
    }
}
