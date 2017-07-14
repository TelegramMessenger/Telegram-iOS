import Foundation

final class OverlayMediaManager {
    var controller: OverlayMediaController?
    
    func attachOverlayMediaController(_ controller: OverlayMediaController) {
        self.controller = controller
    }
}
