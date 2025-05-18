import Foundation
import UIKit
import AsyncDisplayKit

final class ChatControllerTitlePanelNodeContainer: ASDisplayNode {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        for subview in self.view.subviews {
            if let result = subview.hitTest(self.view.convert(point, to: subview), with: event) {
                return result
            }
        }
        return nil
    }
}
