import Foundation
import AsyncDisplayKit

final class ChatControllerTitlePanelNodeContainer: ASDisplayNode {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if self.bounds.contains(point) {
            var foundHit = false
            for subnode in self.subnodes {
                if subnode.frame.contains(point) {
                    foundHit = true
                    break
                }
            }
            if !foundHit {
                return nil
            }
        }
        return super.hitTest(point, with: event)
    }
}
