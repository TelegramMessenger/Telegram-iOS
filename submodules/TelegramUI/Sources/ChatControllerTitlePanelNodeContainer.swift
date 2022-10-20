import Foundation
import UIKit
import AsyncDisplayKit

final class ChatControllerTitlePanelNodeContainer: ASDisplayNode {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if self.bounds.contains(point) {
            if let subnodes = self.subnodes {
                for subnode in subnodes {
                    if subnode.frame.contains(point) {
                        if let result = subnode.view.hitTest(self.view.convert(point, to: subnode.view), with: event) {
                            return result
                        }
                    }
                }
            }
            return nil
        }
        return super.hitTest(point, with: event)
    }
}
